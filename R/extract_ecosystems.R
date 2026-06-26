#-----------------------------------------------------------------------------#
#' Build database
#' @param path Path to processing environment directory.
#' @return an SQLite database.
#' @importFrom RSQLite SQLite
#' @importFrom sf sf_use_s2 st_read
#' @importFrom plyr ddply summarise
#' @importFrom terra xyFromCell rast rasterize vect extract
#' @importFrom readr read_delim write_csv
#' @importFrom yaml read_yaml
#' @importFrom geosphere distHaversine
#' @importFom GlobES.validation exponential_decay
#' @importFrom DBI dbConnect dbGetQuery dbDisconnect
#' @details Compiles clean species observations into a common SQLite database.
#' @export
#-----------------------------------------------------------------------------#

extract_ecosystems = function(species, path) {

  # load configuration file
  config = read_yaml(config_path)

  ## extract information on the species ---
  ##============================================================================#

  # load files with information on the target species
  iname = file.path(path, config$info$taxonomy)
  taxonomy = read_delim(iname, num_threads=1, show_col_types=F, progress=F)
  iname = file.path(path, config$info$habitats)
  habitats = read_delim(iname, num_threads=1, show_col_types=F, progress=F)

  # extract species-specific taxonomic and observation information
  taxonomy = taxonomy[which(taxonomy$scientificName == species)]
  gbif_id = paste0(strsplit(taxonomy$gbif_id,"[;]")[[1]], collapse=",")
  ind = which(habitat$scientificName == species)
  iucnKey = habitat$internalTaxonId[ind[1]]
  info = habitat[ind,]
  kingdom = info$kingdom[1]

  ## extract range map ----
  ##============================================================================#

  # build query to locate the geometry for sp
  sql_query = paste0('SELECT * FROM ', kingdom, ' WHERE (binomial = "', species,
                     '") AND (presence = 1) AND (origin = 1) AND (seasonal <= 3)')

  # access raster with range geometry
  sf_use_s2(FALSE)
  range_data = file.path(path, config$range_maps[[toupper(kingdom)]])
  range_geom = st_read(range_data, query=sql_query, quiet=T)

  if (nrow(range_geom) == 0) {
    print(paste0('no range map for ', species))
    next
  }

  ## extract samples ----
  ##==========================================================================#

  # build query to locate the geometry for sp
  query = paste0('SELECT * FROM occurrences WHERE taxonKey IN (', gbif_id ,')')

  # retrieve samples from database
  iname = file.path(working_dir, config$gbif$database)
  db = dbConnect(SQLite(), iname)
  samples = as.data.frame(dbGetQuery(db, query))
  dbDisconnect(db)

  if (nrow(samples) == 0) {
    print(paste0('no observation points for ', species))
    next
  }

  # report number of samples per year
  count_data = ddply(samples, .(species,year), summarise, count=length(year))
  oname = file.path(path, 'tmp', 'nr_samples', paste0(iucnKey, '_nr_samples.csv'))
  write_csv(count_data, oname, progres=F, num_threads=1)

  rm(count_data)
  invisible(gc())

  if (nrow(samples) == 0) {
    print(paste0('no observation points for ', species))
    next
  }

  ## filter samples based on distance to the centroid of the pixel ----
  ##==========================================================================#

  # get coordinates of the center of the pixel on which an observation lays
  xy0 = as.matrix(samples[,c('decimalLongitude', 'decimalLatitude')])
  samples$cell = cellFromXY(sample_reference, xy0)
  xy1 = xyFromCell(sample_reference, samples$cell)

  # get the distance between the center of the pixel and its edge
  xy2 = xy1
  xy2[,1] = xy2[,1]+config$resolution/2 # set coordinate to right edge of pixel

  # distance in meters between the center and edge of a pixel
  edge_distance = distHaversine(xy1, xy2)

  # distance in meters between the center of the pixel and the observation
  samples$xy_uncertainty =
    distHaversine(xy0, xy1) + # observation-centroid distance
    samples$coordinateUncertaintyInMeters + # uncertainty of species location
    samples$coordinatePrecision # uncertainty of coordinate location

  # exclude species observations non contained by their corresponding pixel
  samples = samples[which(samples$xy_uncertainty < edge_distance),]

  rm(edge_distance, xy0, xy1, xy2)

  ## summarize samples to unique pixel positions at unique years ----
  ##==========================================================================#

  samples = ddply(samples,
                  .(cell,year), summarise,
                  x=mean(decimalLongitude),
                  y=mean(decimalLatitude),
                  xy_uncertainty=mean(xy_uncertainty),
                  nr_records=length(year))

  invisible(gc())

  if (nrow(samples) == 0) {
    print(paste0('no observation points for ', species))
    next
  }

  # add species name for harmonization (names in GBIF may vary)
  samples$scientificName = species

  ## filter samples according to elevation ranges ----
  ##==========================================================================#

  ranges = read_delim(file.path(working_dir, config$info$elevation_ranges),
                      num_threads=1, show_col_types=F, progres=F)

  # extract elevation for each sample
  iname =  file.path(working_dir, config$elevation)
  elevation = extract(rast(iname), samples[,c('x','y')])[[2]]

  # subset samples to those within the elevation ranges
  ind = which(ranges$scientificName == species)
  ind = which((elevation >= ranges$lower[ind]) &
                (elevation <= ranges$upper[ind]))
  samples = samples[ind,]

  if (nrow(samples) == 0) {
    print(paste0('no observation points for ', species))
    next
  }

  rm(ind, elevation)
  invisible(gc())

  ## write copies of samples for each ecosystem the species belongs to ----
  ##==========================================================================#

  for (s in 1:length(config$range_maps$season)) {

    # target ecosystem types
    si = which(info$season == config$range_maps$season[[s]][1])
    gi = which(range_geom$seasonal %in% config$range_maps$season[[s]][2])

    if (length(si) > 0) {

      # identifier(s) of ecosystem type(s)
      ecosystems = info$class_id[si]

      # build range map with target polygons
      rm = rasterize(vect(range_geom), range_reference,
                     background=0, touches=TRUE)

      # subset data to samples with valid observations
      odf = samples[which(extract(rm,samples[,c('x','y')])[[2]] == 1),]

      # save a copy of the map for each ecosystem
      if (nrow(odf) > 0) {

        odf$specialisation = exponential_decay(length(ecosystems),
                                               config$specialization_lambda)

        for (eco in ecosystems) {
          oname = file.path(working_dir, 'tmp', 'samples',
                            paste0(eco, '_', iucnKey, '_spOccurrences.csv'))
          write_csv(odf, oname, progres=F, num_threads=1)
        }
      }
    }
  }



}

