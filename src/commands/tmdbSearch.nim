import uri
import ../discord
import httpclient
import ../utils
import json
import strutils
import asyncdispatch
import options
import ../config

const baseURL = "https://api.themoviedb.org/3/search"

proc searchTmdb*(m: Message, isMovie: bool) {.async.} =
    let client = newAsyncHttpClient()
    let message = m.clean()
    let searchTerm = encodeUrl(message.split(if isMovie: " movie " else: " tv ", maxSplit=1)[1].strip())
    let basePath = baseURL & (if isMovie: "/movie" else: "/tv")
    let response = await client.request(basePath & "?api_key=" & TMDB_API_KEY & "&query=" & searchTerm, httpMethod=HttpGet)
    case response.code:
    of Http200:
        let jsonBody = await response.json
        let results = jsonBody["results"].getElems()
        if len(results) == 0:
            asyncCheck m.reply("couldn't find it")
            return
            
        let movie = results[0]
        let poster = "https://image.tmdb.org/t/p/original" & movie["poster_path"].getStr()
        let title = movie[if isMovie: "title" else: "name"].getStr()
        let overview = movie["overview"].getStr()
        
        let embed = some Embed(
            title: some title,
            description: some overview,
            image: some EmbedImage(
                url: some poster
            ),
            footer: some EmbedFooter(
                text: "Data is from The Movie Database"
            )
        )
        asyncCheck m.reply(body = "", embed = embed)
        
    of Http404:
        asyncCheck m.reply("couldn't find it")
        return

    else:
        return
        
