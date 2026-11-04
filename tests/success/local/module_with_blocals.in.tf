module "test_module" {
  source = "./some_module"

  blocals {
    foo = "foo"
    bar = "${blocal.foo} bar"
  }

  use_blocal_foo = blocal.foo
  use_blocal_bar = blocal.bar
}
