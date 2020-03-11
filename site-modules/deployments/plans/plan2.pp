plan deployments::plan2(
){
  $result = servicenow_integration::testfunction('hello')
  file::write('/root/testoutput.txt', $result)
}
