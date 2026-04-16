// note
// - We process the given source file in 2-pass:
//     1. Collect macro definitions in the source file and also in included files.
//     2. Convert the content of the source file.
//   This way we know beforehand what we need to replace when we visit HCL2 expressions.
// - Throughout this program we halt execution with nonzero exit code when something goes
//   wrong (using `eprintln_exit!`), instead of the usual `Result`-based error handling.
//   This is due to the API of hcl-edit where `visit_*_mut` trait methods are required to
//   return `()`.

use clap::Parser;
use hcl_edit::expr::{
    Conditional, Expression, FuncArgs, FuncCall, Parenthesis, Traversal, TraversalOperator,
};
use hcl_edit::structure::{Attribute, Block, BlockLabel, Body};
use hcl_edit::template::{Element, Interpolation, StringTemplate};
use hcl_edit::visit_mut::{self, VisitMut};
use hcl_edit::{Decor, Decorate, Decorated, Ident};
use std::collections::hash_map::Entry;
use std::collections::{HashMap, HashSet};
use std::ffi::OsStr;
use std::fmt::Debug;
use std::fs::read_to_string;
use std::path::{Path, PathBuf};

//
// utils
//
macro_rules! eprintln_exit {
    ($($arg:tt)*) => {{
        eprintln!($($arg)*);
        std::process::exit(1);
    }};
}

fn increment_and_check_expansion_count(
    expansion_type: &str,
    name: &str,
    counts: &mut HashMap<String, u32>,
) {
    let count = counts
        .entry(name.to_string())
        .and_modify(|c| *c += 1)
        .or_insert(1);
    if *count > 100 {
        eprintln_exit!("Too many expansions of {} '{}'.", expansion_type, name);
    }
}

fn replace_ident(ident: &mut Decorated<Ident>, new_ident: &str) {
    let i = ident.value_mut();
    *i = Ident::new(new_ident);
}

fn decorate_ident(prefix: &str, ident: Ident) -> Decorated<Ident> {
    Decorated::new(ident).decorated(Decor::new(prefix, " "))
}

fn wrap_with_paren(expr: Expression) -> Expression {
    // When we print the converted AST, parentheses are not automatically
    // added; we need to wrap the expression with parenthesis in order not to
    // mess up with the operator precedence in the generated code.
    Expression::from(Parenthesis::new(expr))
}

fn parse_file<P: AsRef<Path> + Debug>(filename: &P, error_msg_suffix: &str) -> Body {
    let Ok(input) = read_to_string(filename) else {
        eprintln_exit!("Failed to read {:?}{}.", filename, error_msg_suffix);
    };
    let Ok(body) = input.parse() else {
        eprintln_exit!(
            "Failed to parse '{:?}' as HCL2{}.",
            filename,
            error_msg_suffix
        );
    };
    body
}

//
// helper to expand 1 variable in expression
//
struct VarExpand<'a, 'b> {
    var_name: &'a str,
    var_expr: &'b Expression,
}

impl VisitMut for VarExpand<'_, '_> {
    fn visit_expr_mut(&mut self, expr: &mut Expression) {
        match expr {
            Expression::Variable(ident) if ident.as_str() == self.var_name => {
                *expr = wrap_with_paren(self.var_expr.to_owned())
            }
            _ => visit_mut::visit_expr_mut(self, expr),
        }
    }
}

fn expand_var(mut expr: Expression, var_name: &str, var_expr: &Expression) -> Expression {
    let mut expand = VarExpand { var_name, var_expr };
    expand.visit_expr_mut(&mut expr);
    expr
}

//
// expand macro body in expression
//
#[derive(Debug)]
struct MacroDefinition {
    arg_names: Vec<String>,
    expression: Expression,
}

type MacrosMap = HashMap<(String, usize), MacroDefinition>;

impl MacroDefinition {
    fn arity(&self) -> usize {
        self.arg_names.len()
    }

    fn from_macro_block(macro_name: &str, block: &Block) -> MacroDefinition {
        let label_strings = block
            .labels
            .iter()
            .map(|l| l.to_string())
            .collect::<Vec<String>>();
        let [_macro_name, arg_names @ ..] = &label_strings[..] else {
            eprintln_exit!(
                "'macro' block without name label is invalid. (should not happen because we obtain the 1st entry before this)"
            );
        };
        let attrs = block.body.attributes().collect::<Vec<&Attribute>>();
        let expr = match attrs.last() {
            Some(last_attr) if last_attr.key.as_str() == "return" => attrs[0..attrs.len() - 1]
                .iter()
                .rfold(last_attr.value.clone(), |expr, attr| {
                    expand_var(expr, attr.key.as_str(), &attr.value)
                }),
            _ => eprintln_exit!(
                "Last attribute of macro '{}' must be 'return = ...'.",
                macro_name
            ),
        };
        MacroDefinition {
            arg_names: arg_names.to_owned(),
            expression: expr,
        }
    }

    fn expand(&self, macro_name: &str, args: Vec<&Expression>) -> Expression {
        if self.arg_names.len() != args.len() {
            eprintln_exit!(
                "Number of args passed to macro '{}' must be '{}'.",
                macro_name,
                self.arg_names.len()
            );
        }
        let new_expr = self
            .arg_names
            .iter()
            .zip(args)
            .fold(self.expression.to_owned(), |expr, (arg_name, arg_expr)| {
                expand_var(expr, arg_name, arg_expr)
            });
        wrap_with_paren(new_expr)
    }
}

//
// recognize macros in input file and also in included files
//
fn extract_macro_blocks_impl(
    filepath: &Path,
    body: &mut Body,
    macros: &mut MacrosMap,
    all_includes: &mut HashSet<PathBuf>,
) {
    let macro_blocks = body.remove_blocks("macro");
    for m in macro_blocks {
        let Some(macro_name) = m.labels.first().map(|l| l.as_str()) else {
            eprintln_exit!("'macro' block without name label is invalid.");
        };
        if macro_name == "pipeline" {
            eprintln_exit!("'pipeline' macro is reserved and cannot be defined.");
        }
        let md = MacroDefinition::from_macro_block(macro_name, &m);
        let Entry::Vacant(entry) = macros.entry((macro_name.to_string(), md.arity())) else {
            eprintln_exit!(
                "Duplicate macro blocks with name '{}' and arity '{}' found in this compilation unit.",
                macro_name,
                md.arity(),
            );
        };
        entry.insert(md);
    }
    let Some(parent_dir) = filepath.parent() else {
        eprintln_exit!("Parent directory of {:?} not found.", filepath);
    };
    let macro_include_blocks = body.remove_blocks("macro_include");
    let mut direct_includes = HashSet::new();
    for mi in macro_include_blocks {
        let attrs = mi.body.attributes().collect::<Vec<_>>();
        let source = match attrs[..] {
            [s] if s.key.as_str() == "source" => s,
            _ => eprintln_exit!(
                "'macro_include' block in {:?} must have exactly one attribute named 'source'.",
                filepath
            ),
        };
        let Expression::String(source_path) = &source.value else {
            eprintln_exit!("Only literal string is allowed for 'source' attribute value.");
        };
        let error_msg_suffix = format!(" (included from {:?})", filepath);
        let Ok(include_path) = parent_dir.join(source_path.as_str()).canonicalize() else {
            eprintln_exit!(
                "Failed to read {}{}.",
                source_path.as_str(),
                error_msg_suffix
            );
        };
        if direct_includes.contains(&include_path) {
            eprintln_exit!(
                "{:?} is included multiple times within {:?}.",
                include_path,
                filepath
            );
        }
        direct_includes.insert(include_path.clone());
        if !all_includes.contains(&include_path) {
            all_includes.insert(include_path.clone());
            let mut body = parse_file(&include_path, &error_msg_suffix);
            extract_macro_blocks_impl(&include_path, &mut body, macros, all_includes);
        }
    }
}

fn extract_macro_blocks(
    macro_prelude_files: &[String],
    target_file: &str,
    body: &mut Body,
) -> MacrosMap {
    let mut macros = HashMap::new();
    let mut all_includes = HashSet::new();
    for prelude_file in macro_prelude_files {
        let mut prelude_body = parse_file(prelude_file, " (given as a macro prelude)");
        extract_macro_blocks_impl(
            Path::new(prelude_file),
            &mut prelude_body,
            &mut macros,
            &mut all_includes,
        );
    }
    extract_macro_blocks_impl(Path::new(target_file), body, &mut macros, &mut all_includes);
    macros
}

//
// convert file contents:
// - process `flocals` and `blocals` blocks
// - replace references to `flocal.xxx`, `blocal.yyy` and `macro::zzz(arg1, arg2)`
//
struct Converter {
    source_basename_without_ext: String,
    blocals: HashMap<String, Expression>,
    blocal_expansion_counts: HashMap<String, u32>,
    macros: MacrosMap,
    macro_expansion_counts: HashMap<String, u32>,
}

impl Converter {
    fn new(filename: &str, macros: MacrosMap) -> Converter {
        let basename = Path::new(filename)
            .file_name()
            .and_then(OsStr::to_str)
            .unwrap();
        let basename_without_ext = basename
            .split_once('.')
            .map(|(t0, _t1)| t0)
            .unwrap_or(basename);
        Converter {
            source_basename_without_ext: basename_without_ext.to_string(),
            blocals: HashMap::new(),
            blocal_expansion_counts: HashMap::new(),
            macros,
            macro_expansion_counts: HashMap::new(),
        }
    }

    fn flocal_to_local_name(&self, name: &str) -> String {
        format!("flocal_{}_{}", self.source_basename_without_ext, name)
    }

    fn canonicalize_flocals_block(&self, block: &mut Block) {
        replace_ident(&mut block.ident, "locals");
        self.add_prefix_to_attr_keys(&mut block.body);
    }

    fn add_prefix_to_attr_keys(&self, body: &mut Body) {
        let attrs = body
            .attributes()
            .map(Attribute::clone)
            .collect::<Vec<Attribute>>();
        for attr in attrs {
            if let Some(mut attr2) = body.remove_attribute(attr.key.as_str()) {
                let new_ident = self.flocal_to_local_name(attr2.key.as_str());
                replace_ident(&mut attr2.key, &new_ident);
                body.push(attr2);
            }
        }
    }

    fn take_blocals_block_if_present(&mut self, node: &mut Block) {
        if let Some(b) = node.body.remove_blocks("blocals").first() {
            for attr in b.body.attributes() {
                let key = attr.key.value().as_str();
                let Entry::Vacant(entry) = self.blocals.entry(key.to_string()) else {
                    eprintln_exit!(
                        "Duplicated key {} in blocals block. (This shouldn't happen because parsing fails if the contents have duplicated attribute keys)",
                        key
                    );
                };
                entry.insert(attr.value.to_owned());
            }
        }
    }

    fn convert_assert_block(&mut self, block: &mut Block) {
        let [BlockLabel::String(decorated)] = &block.labels[..] else {
            eprintln_exit!("Exactly 1 label is expected for 'assert' block.");
        };
        let label_str = decorated.as_str().to_string();
        let Some(cond) = block.body.remove_attribute("condition") else {
            eprintln_exit!("Attribute 'condition' must be given to 'assert' block.");
        };
        replace_ident(&mut block.ident, "locals");
        block.labels = vec![];
        let local_name = format!("assert_{}_{}", self.source_basename_without_ext, label_str);
        block.body.push(Attribute::new(
            decorate_ident(
                "  # tflint-ignore: terraform_unused_declarations\n  ",
                Ident::new(local_name),
            ),
            Conditional::new(
                wrap_with_paren(cond.value.clone()),
                format!("ASSERTION OK: {}", label_str),
                // We use `tobool("not a bool")` to raise an error from terraform configuration.
                // This is a workaround for missing support of raising an error.
                // note:
                // - `precondition` in lifecycle block requires us to introduce either resource,
                //   data source or output. They will introduce unwanted changes in .tfstate files.
                // - `check` block does not halt execution on assertion failure.
                FuncCall::new(
                    Ident::new("tobool"),
                    // Embed the condition expression into the error message so that terraform
                    // shows the details of the expression.
                    FuncArgs::from(vec![Expression::from(StringTemplate::from(vec![
                        Element::from(format!(
                            "ASSERTION FAILED: {} in file '{}': condition=",
                            label_str, self.source_basename_without_ext,
                        )),
                        Element::from(Interpolation::new(cond.value.clone())),
                    ]))]),
                ),
            ),
        ));
    }
}

impl VisitMut for Converter {
    fn visit_block_mut(&mut self, node: &mut Block) {
        match node.ident.value().as_str() {
            "resource" | "module" => self.take_blocals_block_if_present(node),
            "flocals" => self.canonicalize_flocals_block(node),
            "assert" => self.convert_assert_block(node),
            _ => (),
        }
        // Continue tree visiting to handle other parts of AST
        visit_mut::visit_block_mut(self, node);
        // Forget about the entries in blocals block (if any)
        self.blocals.clear();
    }

    fn visit_traversal_mut(&mut self, node: &mut Traversal) {
        match &mut node.expr {
            Expression::Variable(ident1) if ident1.as_str() == "flocal" => {
                replace_ident(ident1, "local");
                if let TraversalOperator::GetAttr(ident2) = node.operators[0].value_mut() {
                    let new_ident2 = self.flocal_to_local_name(ident2.as_str());
                    replace_ident(ident2, &new_ident2);
                }
            }
            Expression::Variable(ident1) if ident1.as_str() == "blocal" => {
                match node.operators[0].value_mut() {
                    TraversalOperator::GetAttr(ident2) => {
                        let blocal_name = ident2.as_str();
                        let Some(expr) = self.blocals.get(blocal_name) else {
                            eprintln_exit!(
                                "'blocal.{}' not present in blocals block.",
                                blocal_name,
                            );
                        };
                        increment_and_check_expansion_count(
                            "blocal",
                            blocal_name,
                            &mut self.blocal_expansion_counts,
                        );
                        node.expr = wrap_with_paren(expr.to_owned());
                        node.operators.remove(0);
                        self.visit_expr_mut(&mut node.expr);
                    }
                    _ => eprintln_exit!(
                        "unexpected AST: Traversal of 'blocal' should be followed by a GetAttr."
                    ),
                }
            }
            _ => visit_mut::visit_traversal_mut(self, node),
        }
    }

    fn visit_expr_mut(&mut self, expr: &mut Expression) {
        if let Expression::FuncCall(call) = expr {
            match &call.name.namespace[..] {
                [ns] if ns.as_str() == "macro" => {
                    let macro_name = call.name.name.as_str();
                    if macro_name == "pipeline" {
                        let mut args_iter = call.args.iter();
                        let Some(e1) = args_iter.next() else {
                            eprintln_exit!("No argument is passed to 'macro::pipeline()'.");
                        };
                        let mut e2 = e1.to_owned();
                        for arg in args_iter {
                            e2 = expand_var(arg.to_owned(), "_", &e2);
                        }
                        *expr = wrap_with_paren(e2);
                    } else {
                        let arity = call.args.len();
                        let key = (macro_name.to_string(), arity);
                        let Some(macro_def) = self.macros.get(&key) else {
                            eprintln_exit!(
                                "Macro named '{}' with arity '{}' not found.",
                                macro_name,
                                arity,
                            );
                        };
                        increment_and_check_expansion_count(
                            "macro",
                            macro_name,
                            &mut self.macro_expansion_counts,
                        );
                        *expr = macro_def.expand(macro_name, call.args.iter().collect::<Vec<_>>());
                    }
                    visit_mut::visit_expr_mut(self, expr);
                }
                _ => visit_mut::visit_func_call_mut(self, call),
            }
        } else {
            visit_mut::visit_expr_mut(self, expr);
        }
    }
}

//
// body of this binary
//
/// Converts a terraform source file containing xenoform syntax extensions into normal
/// terraform code. The result is printed to STDOUT.
///
/// See https://github.com/flywheel-jp/xenoform/blob/main/README.md for the supported
/// syntax extensions.
#[derive(Parser)]
struct Cli {
    /// File to preprocess using xenoform.
    target_file: String,

    /// File path to be included before processing the target file.
    ///
    /// In the target file you can use macros defined in the included files.
    /// You can include multiple files by repeating `--macro-prelude <FILE>`.
    #[arg(long, value_name = "FILE")]
    macro_prelude: Vec<String>,
}

fn main() {
    let cli = Cli::parse();
    let mut body = parse_file(&cli.target_file, "");
    let macros = extract_macro_blocks(&cli.macro_prelude, &cli.target_file, &mut body);
    let mut converter = Converter::new(&cli.target_file, macros);
    converter.visit_body_mut(&mut body);
    println!("{body}");
}
