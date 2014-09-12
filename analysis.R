library(RNeo4j)

graph = startGraph("http://localhost:2873/db/data/")

query = "
MATCH (:Scrobble)-[:PLAYED]->(:Track)-[:SUNG_BY]->(a:Artist)
RETURN a.name AS Artist, COUNT(*) AS Count
ORDER BY Count DESC
LIMIT 10
"

data = cypher(graph, query)

query = "
MATCH (s:Scrobble)
RETURN s.artist, COUNT(s.artist) as count
ORDER BY count desc limit 10
"