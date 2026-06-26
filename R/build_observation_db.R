#-----------------------------------------------------------------------------#
#' Build database
#' @param path Path to processing environment directory.
#' @return an SQLite database.
#' @importFrom RSQLite SQLite
#' @importFrom DBI dbConnect dbExecute dbWriteTable dbAppendTable dbDisconnect
#'
#' @details Compiles clean species observations into a common SQLite database.
#' @export
#-----------------------------------------------------------------------------#

build_observation_db = function(path) {

  ## check input parameters ----
  ##==========================================================================#

  if (!dir.exists(path)) stop("'path' is not a valid directory")

  tmp_path = file.path(path, "tmp")
  if (!exists(tmp_path))
    stop("missing key directories; use build_environment()")

  # load configuration file
  file_path = file.path(path, "config.yml")
  if (!file.exists(file_path))
    stop("no configuration file; use configure_environment()")
  config = read_yaml(file_path)

  ## create or access target database ----
  ##==========================================================================#

  ## access point to new database (a new one is created if needed)
  db_file = file.path(path, config$observation_db)
  if (file.exists(db_file)) control = FALSE else control = TRUE
  db = dbConnect(SQLite(), db_file)

  ## format SQLite database for faster access ----
  ##==========================================================================#

  dbExecute(db, 'PRAGMA cache_size = 1000000')
  dbExecute(db, 'PRAGMA auto_vacuum = FULL')
  dbExecute(db, 'PRAGMA synchronous=OFF')
  dbExecute(db, 'PRAGMA journal_mode=MEMORY')
  dbExecute(db, 'PRAGMA journal_mode=TRUNCATE')

  ## process data files ----
  ##==========================================================================#

  # list input files
  files = list.files(file.path(path, "tmp"), "cleanObs_.*.csv", full.names=T)

  # write first table
  if (control) {
    data_chunk = read.csv(files[1])
    dbWriteTable(conn=db, name="occurrences", value=data_chunk)
    ind = 2:length(files)
  } else {
    ind = 1:length(files)
  }

  # append remaining tables
  for (i in ind) {
    dbAppendTable(conn=db, name="occurrences", value=read.csv(files[i]))
    invisible(gc())
    print(i)
  }

  # disconnect to preserve data
  dbDisconnect(db)

  ## Index data for quicker searches ----
  ##==========================================================================#

  db = dbConnect(SQLite(), db_path)
  dbExecute(db, 'CREATE INDEX taxonkey_idx ON occurrences (taxonKey)')
  dbExecute(db, 'VACUUM;')
  dbDisconnect(db)

  file.remove(files)

}
