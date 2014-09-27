# Don't run this while currently scrobbling. 
# The now-playing track will not have a timestamp, which'll mess everything up.
options(stringsAsFactors = F)

library(RCurl)
library(jsonlite)
library(dplyr)

# REST API things.
REST_URL = "http://ws.audioscrobbler.com/2.0/"
API_KEY = Sys.getenv('LASTFM_KEY')

# Function for getting scrobble history and writing to csv.
get_scrobbles <- function(user) {
  # Convert JSON to data frame.
  clean <- function(json) {
    data = fromJSON(json)
    data = data$recenttracks$track
    
    data = data.frame(user = user, 
                      track = data$name, 
                      artist = data$artist$'#text', 
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
                   user = user,
                   api_key = API_KEY,
                   limit = 200,
                   to = max_unix,
                   format = "json")
    
    new_data = try(clean(json), silent = T)
    
    # There will be an error in clean() if no additional data is returned.
    if(class(new_data) == "try-error") {
      print("All scrobbles found.")
      break
    }
    
    # Append new data.
    data = rbind(data, new_data)
    print(paste(nrow(new_data), "scrobbles added for a total of", nrow(data), "scrobbles."))
    
    # Update max timestamp to get next 200 scrobbles.
    max_unix = min(new_data$timestamp)
    Sys.sleep(5)
  }
  
  # Reorder scrobbles by timestamp ascending.
  data = arrange(data, timestamp)
  
  # Write to csv.
  write.csv(data, file = paste(Sys.Date(), user, 'scrobbles.csv', sep = "_"), row.names = F)
}

# Get scrobble history for me and my friends.
get_scrobbles("nmwhite0131")
get_scrobbles("smooligans")
get_scrobbles("aaronsrun")
