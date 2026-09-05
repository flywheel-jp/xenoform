module "test_module" {
  source = "./some_module"

  use_blocal_foo = ( "foo")
  use_blocal_bar = ( "${( "foo")} bar")
}

