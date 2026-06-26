#' Build project data structure on which to process species occurrences.
#' @param path Directory where data structure will be built.
#' @importFrom zen4R download_zenodo
#' @return A standardized file structure.
#' @details {Returns a standardized data structure created in \emph{path}
#' to standardize the development and usage of validation data. The output
#' folder will include aREADME.txt file describing the intended purpose of
#' each folder, namely:
#' \itemize{
#'   \item{\emph{data -} Storage of processed data and parameter files.}
#'   \item{\emph{analysis -} Output of data analyses, including plots.}
#'   \item{\emph{tmp - Temporary folder to store intermediate outputs.}}
#' }
#' In addition, the data structure is populated with key input data,
#' including species range maps, configuration files (e.g., data on
#' species-specific habitat preferences from the IUCN Red list of
#' species), and geospatial data on per-pixel elevation.}
#'
#' @export

#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

build_environment = function(path) {

  ## Check input argument ----
  ##==========================================================================#

  if (!exists(path)) stop("'path' not found")

  ## create folder structure ----
  ##==========================================================================#

  target_dir = file.path(path, '00_data')
  if (!dir.exists(target_dir)) dir.create(target_dir)

  target_dir = file.path(path, '01_analysis')
  if (!dir.exists(target_dir)) dir.create(target_dir)

  target_dir = file.path(path, '02_documents')
  if (!dir.exists(target_dir)) dir.create(target_dir)

  target_dir = file.path(path, '03_code')
  if (!dir.exists(target_dir)) dir.create(target_dir)

  target_dir = file.path(path, 'tmp')
  if (!dir.exists(target_dir)) dir.create(target_dir)

  ## Describe folder structure within a README ----
  ##==========================================================================#

  sink(file.path(out.path, 'README.txt'))
  cat("Data structure description:")
  cat("\n")
  cat("data - Storage of processed data and parameter files.")
  cat("\n")
  cat("analyses - output of data analyses, including plots.")
  cat("\n")
  cat("tmp - temporary folder to store intermediate outputs.")
  sink()

  ## Populate the data folder ----
  ##==========================================================================#

  # download data
  download_zenodo(doi="", path=target_dir, quiet=T)

  # import download into data folder
  tmp_file = list.files(target_dir, "GlobES.*.zip")
  unzip(tmp_file, exdir=file.path(path, "data"))

  # delete temporary file
  file.remove(tmp_file)

}
