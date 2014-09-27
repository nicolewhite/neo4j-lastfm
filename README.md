last_fm_graph
=============

To create your own Neo4j graph database of any users' scrobble histories:

* [Install Neo4j and RNeo4j](http://nicolewhite.github.io/RNeo4j/).
* [Get a Last.fm API key](http://www.last.fm/api/account/create).
* Run `get_data.R`, replacing the usernames in `get_scrobbles()` with the usernames you want.
* Run `upload_data.R`.
* If you want genre information added to the graph, run `update_db.R`.


<a href="https://pbs.twimg.com/media/BxsmjLJIgAA068n.png:large" target="_blank"><img src="https://pbs.twimg.com/media/BxsmjLJIgAA068n.png:large" width="100%" height="100%"></a>