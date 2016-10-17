#.Rprofile
# enables dev_mode:

if (require(devtools, quietly=TRUE)) {
  devtools::dev_mode(on=TRUE, path=file.path(getwd(),'lib'))
} else {
  add <- getwd()
  if (basename(getwd()) == 'stuff') add <- file.path(add, '..')
  .libPaths(file.path(add,'lib'))
}
