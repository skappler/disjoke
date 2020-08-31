import allographer/schema_builder
import allographer/query_builder
export query_builder
import httpclient
import dimscord
import asyncdispatch
import strformat
import json
import random
import macros
import logging
import options
import utils
randomize()
schema([
    table("posts", [
        Column().string("id"),
        Column().string("title"),
        Column().string("url"),
        Column().string("selftext"),
        Column().string("subreddit")
    ])
])


type 
    Needs* = enum
        Title,
        Image,
        Body
        

    Subreddit = object
        subreddit*: string
        needs*: seq[Needs]
        command*: string

    RedditPost = object
        subreddit: string
        title: string
        url: string
        selftext: string
        pinned: bool
        id: string

proc newSubreddit*(subreddit, command: string, needs: varargs[Needs]): Subreddit = Subreddit(subreddit: subreddit, needs: toSeq(needs), command: command)

const subreddits* = @[
    newSubreddit("memes", "meme", Title, Image),
    newSubreddit("jokes", "joke", Title, Body)
]

proc getPost*(subreddit: Subreddit): tuple[body: string, embed: Option[Embed]]=
    let post = RDB().table("posts").select("url", "selftext", "title").where("subreddit", "=", subreddit.subreddit).orderBy("RANDOM()", Desc).first()
    echo(post)
    let needs = subreddit.needs
    var embed = none(Embed)
    var body = ""
    # Not the best way but it works
    if needs.contains(Image):
        embed = some Embed(
            image: some(EmbedImage(url: some(post["url"].getStr()))),
            title: if needs.contains(Title): some(post["title"].getStr()) else: none(system.string),
            description: if needs.contains(Body): some(post["selftext"].getStr()) else: none(system.string)
        )
        
    elif needs.contains(Title) and needs.contains(Body):
        body = post["title"].getStr() & "\n" & post["selftext"].getStr()

    elif needs.contains(Body):
        body = post["selftext"].getStr()

    elif needs.contains(Title):
        body = post["title"].getStr()

    return (body: body, embed: embed)

macro generateRedditCommands(subreddits: seq[Subreddit]): untyped =
    result = newStmtList()
    for subreddit in subreddits:
        var commandTree = newTree(nnkStmtList)
        let commandBody = newTree(nnkStmtList, newCommentStmtNode("test"))
        commandBody.add(nnkAsgn.newTree(newIdentNode("sub"), newLit(subreddit)))
        commandBody.add(parseStmt("let post = getPost(sub)"))
        commandBody.add(nnkCommand.newTree(newIdentNode("await"), newCall("reply", newIdentNode("m"), newLit("hello"))))
        commandTree.add(newStrLitNode("gimme fat"))
        commandTree.add(commandBody)
        result.add(commandTree)
        
proc getPosts(client: AsyncHttpClient, subreddit, sort, time: string, limit: int = 100, includePinned: bool = false): Future[seq[RedditPost]] {.async.} =
    let url = fmt"https://www.reddit.com/r/{subreddit}/{sort}.json?limit={limit}&t={time}"
    let jsonBody = parseJson(await client.getContent(url))
    for post in jsonBody["data"]["children"].getElems():
        if post["data"]["stickied"].getBool() == false or includePinned:
            result &= post["data"].to(RedditPost)

proc getPostsService*() {.async.} =
    var hasData = false
    while true:
        let client = newAsyncHttpClient()
        for subreddit in subreddits:
            transaction:
                Info.echo("Updating subreddit: " & subreddit.subreddit)
                let posts = await client.getPosts(subreddit.subreddit, "hot", "hour")
                if hasData:
                    RDB().table("posts").where("subreddit", "=", subreddit.subreddit).delete()

                for post in posts:
                    RDB().table("posts").insert(%*{
                        "id": post.id,
                        "title": post.title,
                        "url": post.url,
                        "selftext": post.selftext,
                        "subreddit": subreddit.subreddit
                    })
        hasData = true
        Info.echo("Done")
        await sleepAsync(3600 * 1000)
        
