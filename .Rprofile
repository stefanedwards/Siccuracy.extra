#.Rprofile
# enables dev_mode:

if (require(devtools, quietly=TRUE)) {
  devtools::dev_mode(on=TRUE, path=file.path(add,'lib'))
} else {
  .libPaths(file.path(add,'lib'),.libPaths())
}
