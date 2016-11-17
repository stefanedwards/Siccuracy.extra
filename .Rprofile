#.Rprofile
# enables dev_mode:

if (require(devtools, quietly=TRUE)) {
  devtools::dev_mode(on=TRUE, path=file.path(getwd(),'lib'))
} else {
  .libPaths(c(file.path(getwd(),'lib'),.libPaths()))
}
