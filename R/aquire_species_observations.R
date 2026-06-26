#-----------------------------------------------------------------------------#
#' Obtain species observation data from GBIF.
#' @param path Path to working directory.
#' @return A CSV table containing observation coordinates.
#' @importFrom yaml read_yaml
#' @importFrom tools md5sum
#' @importFrom rgbif occ_download pred_in pred_gte pred_lte occ_download_wait occ_download_get
#' @details {Function to download GBIF observations given parameters specified
#' in a configuration file included in the working directory. The function
#' assumes that a data structure is in place to allow download (built with
#' \code{\link[build_environment]), and that the specified parameters were
#' modified where required (using \code{\link[configure_project]). The
#' obtained data is accompanied by an RDS file containing its citation.}
#' @export
#-----------------------------------------------------------------------------#

aquire_gbif_data = function(path, year) {

  ## check input & prepare working environment ----
  ##==========================================================================#

  if (!dir.exists(path))
    stop("'path' is not a valid directory")

  tmp_path = file.path(path, "tmp")
  if (!exists(tmp_path)) stop("missing key directories; use build_environment()")

  # load configuration file
  config = read_yaml(file.path(path, "config.yml"))

  ## extract GBIF identifiers for the target species ----
  ##==========================================================================#

  # extract species-specific taxonomic and observation information
  taxonomy = taxonomy[which(taxonomy$scientificName == species)]
  gbif_id = paste0(strsplit(taxonomy$gbif_id,"[;]")[[1]], collapse=",")
  ind = which(habitat$scientificName == species)
  iucnKey = habitat$internalTaxonId[ind[1]]
  info = habitat[ind,]
  kingdom = info$kingdom[1]


  gbif_id = unlist(lapply(info$gbif_id, function(i) strsplit(i, ";")[[1]]))

  ## create and submit request for data from GBIF ----
  ##==========================================================================#

  data_request = occ_download(
    pred_in("taxonKey", gbif_id), # species ID's
    pred_in("basisOfRecord", # data source
            c('HUMAN_OBSERVATION','MACHINE_OBSERVATION','OBSERVATION')),
    pred("hasCoordinate", TRUE), # exclude obs. without coordinates
    pred("hasGeospatialIssue", FALSE), # exclude obs. with known spatial issues
    pred("year", year), # specify the year for data acquisition
    format = "SIMPLE_CSV",
    user=config$rgbif$user, pwd=config$rgbif$pwd
  )

  ## obtain requested data ----
  ##==========================================================================#

  # wait to finish processing
  occ_download_wait(data_request)

  # download when ready
  occ_download_get(data_request, path=tmp_path)

  # preserve citation of the GBIF item used
  data_citation = gbif_citation(data_request)
  saveRDS(data_citation, file=file.path(tmp_path, "gbif_citation.rds"))

  # extract CSV with species observations from ZIP file
  data_key = occ_download_meta(data_request)$key
  zip_file = file.path(tmp_path, paste0(data_key, ".zip"))
  zip_check = md5sum(zip_file)[[1]] # control variable
  csv_file = file.path(tmp_path, paste0(data_key, ".csv"))
  unzip(zip_file, exdir=tmp_path)
  if (zip_check == md5sum(csv_file)) file.remove(zip_file) # delete zip file

}
