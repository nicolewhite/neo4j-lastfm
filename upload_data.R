options(stringsAsFactors = F)

csvs = list.files(pattern = "*.csv")

data = data.frame()

for(i in 1:length(csvs)) {
  new_data = read.csv(csvs[i])
  data = rbind(data, new_data)
}

nrow(data)

names(data)

# Connect to graph db and add uniqueness constraints.
library(RNeo4j)

graph = startGraph("http://localhost:7474/db/data/")

addConstraint(graph, "User", "username")
addConstraint(graph, "Artist", "name")

# Define import query.
query = "
CREATE (scrobble:Scrobble {date:{date},timestamp:TOINT({timestamp})})

MERGE (user:User {username:{user}})
MERGE (artist:Artist {name:{artist}})
MERGE (track:Track {name:{track},artist:{artist}})

MERGE (user)-[:SCROBBLED]->(scrobble)
MERGE (scrobble)-[:PLAYED]->(track)
MERGE (track)-[:SUNG_BY]->(artist)

WITH user, scrobble
MATCH (user)-[:SCROBBLED]->(prev:Scrobble)
WHERE prev.timestamp < scrobble.timestamp AND NOT((prev)-[:NEXT]->(:Scrobble))
MERGE (prev)-[:NEXT]->(scrobble)
"

# Start timer.
start = proc.time()

# Start initial transaction.
tx = newTransaction(graph)

for (i in 1:nrow(data)) {
  # Upload in blocks of 1000.
  if(i %% 1000 == 0) {
    # Commit current transaction.
    commit(tx)
    print(paste("Batch", i / 1000, "committed."))
    # Open new transaction.
    tx = newTransaction(graph)
  }
  
  # Append paramaterized Cypher query to transaction.
  appendCypher(tx,
               query,
               date = data$date[i],
               timestamp = data$timestamp[i],
               user = data$user[i],
               artist = data$artist[i],
               track = data$track[i])
}

# Commit last transaction.
commit(tx)
print("Last batch committed.")
print("All done!")

# Show duration of upload.
proc.time() - start

# Get my 5 most recent scrobbles.
query = "
MATCH (:User {username:'nmwhite0131'})-[:SCROBBLED]->(s:Scrobble),
      recent = (:Scrobble)-[:NEXT*4]->(s)
WHERE NOT ((s)-[:NEXT]->(:Scrobble))
WITH NODES(recent) AS scrobbles
UNWIND scrobbles AS s
MATCH (s)-[:PLAYED]->(t:Track)-[:SUNG_BY]->(a:Artist)
RETURN s.date, t.name, a.name
"

cypher(graph, query)