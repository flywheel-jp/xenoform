resource "someprovider_someresource" "xxx" {

  some_block {}
  use_blocal_foo = ( "foo")
  use_blocal_bar = ( "${( "foo")} bar")
}

