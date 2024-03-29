#' Get api metadata for each table
#' A function to read into R metadata which are stored in api table 2 
#' @param tabell_id a code name for dataset
#'
#' @return metadata as a table in csv format
#' @export
#'
#' @examples dbh_metadata(907)
dbh_metadata <- function(tabell_id)
{
  url_meta = "https://api-stage.nsd.no/dbhapitjener/Tabeller/bulk-csv-stream?rptNr=002"
  res <- httr::GET(url_meta)
  res <- httr::content(res, as = "text")
  metadata = readr::read_delim(res,
    delim = ",",
    col_types = readr::cols(.default = readr::col_character()),
    locale = readr::locale(decimal_mark = "."),
    na = "",
    trim_ws = TRUE, progress = readr::show_progress()
  )
  
  metadata = dplyr::filter(metadata, `Tabell id` == tabell_id)
  metadata = dplyr::mutate(metadata, Numeric_variable = ifelse(Datatype %in% c("char", "varchar", "nchar"), FALSE,TRUE))
  
  return(metadata)
  
}
