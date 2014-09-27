library(RNeo4j)
library(RCurl)
library(jsonlite)
library(dplyr)

# REST API things.
REST_URL = "http://ws.audioscrobbler.com/2.0/"
API_KEY = Sys.getenv('LASTFM_KEY')

# Get list of artist names.
artists = getLabeledNodes(graph, "Artist")
artists = sapply(artists, function(a) a$name)

length(artists)

# Define import query.
query = "
MATCH (artist:Artist {name:{artist}})
MERGE (genre:Genre {name:UPPER({genre})})
MERGE (artist)-[:MEMBER_OF]->(genre)
"

# Open initial transaction.
tx = newTransaction(graph)

for(i in 1:length(artists)) {
  # Upload in blocks of 100.
  if(i %% 100 == 0) {
    # Commit current transaction.
    commit(tx)
    # Open new transaction.
    tx = newTransaction(graph)
  }
  json = getForm(REST_URL,
                 method = "artist.gettoptags",
                 artist = artists[i],
                 api_key = API_KEY,
                 format = "json")
  
  genre = fromJSON(json)$toptags$tag$name[1]
  
  if(!is.null(genre)) {
    appendCypher(tx, query, artist = artists[i], genre = genre)
  }
}

# Commit last transaction.
commit(tx)