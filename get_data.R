library(RCurl)
library(RNeo4j)
library(jsonlite)
library(dplyr)

setwd('~/Documents/GitHub/last_fm_graph')

# REST API things.
REST_URL = "http://ws.audioscrobbler.com/2.0/"
USER = "smooligans"
API_KEY = Sys.getenv('LASTFM_KEY')

# Convert JSON to data frame.
clean = function(json) {
  data = jsonlite::fromJSON(json)
  data = data$recenttracks$track
  
  data = data.frame(user = USER, 
                    track = data$name, 
                    artist = data$artist$'#text', 
                    album = data$album$'#text', 
                    date = data$date$'#text', 
                    timestamp = data$date$uts)
  return(data)
}

# Start with the timestamp of the current time.
max_unix = as.numeric(strftime(as.POSIXct(Sys.time()), '%s'))

data = data.frame()

# Work backward through user's scrobble history.
repeat{
  json = getForm(REST_URL,
                 method = "user.getrecenttracks",
                 user = USER,
                 api_key = API_KEY,
                 limit = 200,
                 to = max_unix,
                 format = "json")
  
  new_data = try(clean(json), silent = T)
  
  if(class(new_data) == "try-error") {
    break
  }
  
  data = rbind(data, new_data)
  print(paste(nrow(new_data), "more records added for a total of", nrow(data), "records."))
  
  max_unix = min(new_data$timestamp)
  Sys.sleep(5)
}

# Reorder data by timestamp ascending.
data = arrange(data, timestamp)

# Write to csv.
write.csv(data, file = paste0(USER, '_scrobbles.csv'), row.names = F)

# Connect to graph db and add uniqueness constraints.
graph = startGraph("http://localhost:2873/db/data/")

addConstraint(graph, "User", "username")
addConstraint(graph, "Artist", "name")

# Define import query.
query = "
CREATE (scrobble:Scrobble {date:{date},timestamp:TOINT({timestamp}),track:{track},artist:{artist}})

MERGE (user:User {username:{user}})
MERGE (artist:Artist {name:{artist}})
MERGE (track:Track {name:{track},artist:{artist}})

FOREACH (a IN (CASE WHEN {album} = '' THEN [] ELSE [{album}] END) |
  MERGE (album:Album {name:a,artist:{artist}})
  MERGE (track)-[:ON]->(album)
  MERGE (album)-[:CREATED_BY]->(artist)
)

MERGE (user)-[:SCROBBLED]->(scrobble)
MERGE (scrobble)-[:PLAYED]->(track)
MERGE (track)-[:SUNG_BY]->(artist)

WITH user, scrobble
MATCH (user)-[:SCROBBLED]->(prev:Scrobble)
WHERE prev.timestamp < scrobble.timestamp AND NOT((prev)-[:NEXT]->(:Scrobble))
MERGE (prev)-[:NEXT]->(scrobble)
"

# Iterate through data frame and upload thru transactional endpoint.
tx = newTransaction(graph)

for (i in 1:nrow(data)) {
  # Upload in blocks of 1000.
  if(i %% 1000 == 0) {
    print("Commiting current transaction...")
    commit(tx)
    
    print("Opening new transaction...")
    tx = newTransaction(graph)
  }
  
  appendCypher(tx,
               query,
               date = data$date[i],
               timestamp = data$timestamp[i],
               user = data$user[i],
               artist = data$artist[i],
               track = data$track[i],
               album = data$album[i])
}

print("Committing last transaction...")
commit(tx)