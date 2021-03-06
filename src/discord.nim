import asyncdispatch, dimscord
import sequtils
export sequtils
import strutils
export strutils
import httpclient
import options
export options
import soundex
import logging
import sugar
export sugar
import random
import macroUtils
import utils
export utils
export random
import reddit
export dimscord
import macros
import strformat
export strformat
import json
export json
import times
export times
export macros
import tables
export tables
import config


var cl*: DiscordClient

template Command*(matches: varargs[string], mentioned = false, exact = true, soundex: bool = false, body: untyped): untyped {.dirty.}=
    body
    break

proc sentenceSound*(input: string): string =
    for word in input.split(" "):
        result &= soundex(word)

proc reply*(message: Message, body: string, embed: Option[Embed] = none(Embed)): Future[Message] {.async, inline.} =
    Debug.echo("replying with: " & body)
    return await cl.api.sendMessage(message.channelId, body, embed = embed)


proc messageHome*(body: string) {.async.} =
    let owner = await cl.api.createUserDm(OWNER_USER_ID)
    asyncCheck cl.api.sendMessage(owner.id, body)

proc mention*(message: Message, input: string): string {.inline.} =
    return input.replace("author", fmt"<@!{message.author.id}>")


type
    wait = object
        eventType: string
        response: Future[string]
        expected: string

# Holds all the waits
var waits*: Table[string, wait]

proc waitFor*(m: Message, eventType, expected: string): Future[string] =
    result = newFuture[string]()
    case eventType:
    of "MESSAGE_CREATE":
        # Waits for the same author to reply
        waits[m.channelId] = wait(eventType: eventType, response: result, expected: expected)
    of "MESSAGE_REACTION_ADD":
        # Waits for a certain emoji to be responded
        waits[m.id] = wait(eventType: eventType, response: result, expected: expected)
    return result


# All the command generation needs to be in one place cause nim doesn't run the other macros before this one
macro genCommandStructure*(body: untyped): untyped =
    # Create the reddit commands
    var redditTree = newStmtList()
    for index in 0..<len(subreddits):
        let subreddit = subreddits[index]
        body.add(
            newStmtList(
                newStrLitNode("gimme " & subreddit.command),
                newStrLitNode("give me " & subreddit.command),
                newStrLitNode("give " & subreddit.command),
                newParam("soundex", "true"),
                newStmtList(
                    newCommentStmtNode("Gets posts from the subreddit r/" & subreddit.subreddit),
                    parseStmt(fmt"let sub = subreddits[{index}]"),
                    parseStmt(fmt"let post = getPost(sub)"),
                    parseStmt("discard await m.reply(post.body, post.embed)")
                )
            )
        )

    result = newStmtList()

    # Create generic text commands
    let generalCommands = parseJson(readFile("src/commands.json")) # Have to use this instead cause parseFile doesn't work at compile time
    echo pretty(generalCommands)
    for commandNode in generalCommands["generalResponses"].pairs:
        var commandBody = newStmtList()
        let strCommand = commandNode.val.getStr()
        if strCommand != "":
            commandBody.add(
                parseStmt(&"discard await m.reply(m.mention(\"{commandNode.val.getStr}\"))")
            )
        else:
            var responsesTree = nnkBracket.newTree()
            for item in commandNode.val.getElems():
                responsesTree.add(newLit(item.getStr()))
            commandBody.add(
                # parseStmt("discard await m.reply(m.mention(sample))")
                nnkDiscardStmt.newTree(
                    newTree(nnkCommand,
                    newIdentNode("await"),
                         newCall("reply",
                             newIdentNode("m"),
                             newCall("mention",
                                 newIdentNode("m"),
                                     newCall("sample", responsesTree)
                                     )
                                 )
                             )
                        )
                )

        body.add(newStmtList(newStrLitNode(commandNode.key),
            newParam("exact", "false"),
            newParam("soundex", "true"),
            commandBody
        ))

    # continues making generic text commands for when mentioned
    for commandNode in generalCommands["mentionedResponses"].pairs:
        var commandBody = newStmtList()
        let strCommand = commandNode.val.getStr()
        if strCommand != "":
            commandBody.add(
                parseStmt(&"discard await m.reply(m.mention(\"{commandNode.val.getStr}\"))")
            )
        else:
            # If it is a list then create a list of all responses and choose random one everytime
            var responsesTree = nnkBracket.newTree()
            for item in commandNode.val.getElems():
                responsesTree.add(newLit(item.getStr()))

            commandBody.add(
            newTree(nnkDiscardStmt,
                nnkCommand.newTree(
                    newIdentNode("await"),
                        newCall("reply",
                            newIdentNode("m"),
                            newCall("sample", responsesTree)
                        )
                    )
                )
            )

        body.add(newStmtList(newStrLitNode(commandNode.key),
            newParam("mentioned", "true"),
            newParam("exact", "false"),
            newParam("soundex", "true"),
            commandBody
        ))


    var helpMessage = "~~A lot of stuff is missing~~ (most is now implemented) since I am rewriting the bot entirely\\nThis is because the old code broke and because I wanted to do it again in a different language\\nUse the report command to tell me if stuff is missing\\n"
    var mentionedHelpMessage = "You need to mention me for these:\\n"

    # Create the different tree paths that the command could be from
    var mentionedCaseTree = newTree(nnkCaseStmt, newIdentNode("sMessage"))
    var mentionedExtraTree = newStmtList()

    var generalCaseTree = newTree(nnkCaseStmt, newIdentNode("sMessage"))
    var generalExtraTree = newStmtList()

    for commandNode in body:
        var commandTree = newStmtList()
        var commandNames: seq[string]
        var normalCommandNames: seq[string]
        var commandSound = ""
        # Parameters of the template Command are used here to be known later
        var mentioned = false
        var exact = true
        var soundex = false

        for paramNode in commandNode:
            ## Finds all the values specified for the command
            case paramNode.kind:
            of  nnkStrLit:
                commandNames.add(sentenceSound(paramNode.strVal))
                normalCommandNames.add(paramNode.strVal)

            of nnkExprEqExpr:
                # I know .boolVal exists, but it doesn't work
                let value = paramNode[1].strVal
                case paramNode[0].strVal:
                of "mentioned": mentioned = value == "true"
                of "exact": exact = value == "true"
                of "soundex": soundex = value == "true"

            of nnkStmtList:
                for n in paramNode:
                    if n.kind == nnkCommentStmt: ## Finds the comment
                        if not mentioned:
                            helpMessage &= "**" & normalCommandNames.join(", ") & "**:\\n\\t" & n.strVal.replace("\n", "\\n").replace("\\n", "\\n\\t") & "\\n"
                        else:
                            mentionedHelpMessage &= "**" & normalCommandNames.join(", ") & "**:\\n\\t" & n.strVal.replace("\n", "\\n").replace("\\n", "\\n\\t") & "\\n"
                        break

                # Adds all the different ways of saying the command
                var commandBody = paramNode
                if not soundex:
                    commandBody = newIfStmt((
                        nnkInfix.newTree(
                            newIdentNode("in"),
                            newLit(normalCommandNames[0]),
                            newIdentNode("message")
                        ), paramNode
                    ))

                var newOfBranch = nnkOfBranch.newTree()
                for command in commandNames:
                    newOfBranch.add(newLit(command))
                newOfBranch.add(commandBody)

                # Checks which branch to add it to
                if mentioned and exact:
                    mentionedCaseTree.add(newOfBranch)
                elif mentioned and not exact:
                    mentionedExtraTree.add(
                        newIfStmt((
                        nnkInfix.newTree(
                            newIdentNode("in"),
                            newLit(commandNames[0]), # TODO allow different stuff
                            newIdentNode("sMessage")
                        ), commandBody))
                    )
                elif not exact:
                    generalExtraTree.add(
                        newIfStmt((
                            nnkInfix.newTree(
                                newIdentNode("in"),
                                newLit(commandNames[0]),
                                newIdentNode("sMessage")
                            ), commandBody
                        ))
                    )
                else:
                    generalCaseTree.add(newOfBranch)
            else:
                continue

    helpMessage &= "\\n" & mentionedHelpMessage
    result.add(parseStmt("let helpMsg {.global.} = " & '"' & helpMessage & '"')) # Make the helpMsg global so it is not recreated every call

    # Add the inexact commands onto the else path of the case statement
    mentionedCaseTree.add(nnkElse.newTree(mentionedExtraTree))
    generalCaseTree.add(nnkElse.newTree(generalExtraTree))

    # Run either the mentioned case tree or non mentioned case tree depending on if the user is mentioned or not
    var mentionedIfStmt = newIfStmt(
        (
            ident("isMentioned"), # If mentioned then check against mentionedCaseTree
                mentionedCaseTree)
    )
    mentionedIfStmt.add(
        nnkElse.newTree(
            generalCaseTree # Else run the general case tree since they are not mentioned
        )
    )
    result.add(mentionedIfStmt)
    echo(astGenRepr(result))

proc postStats*(r: Ready) {.async.} =
    ## Updates the bots count on top.gg
    # TODO move to a different file
    when declared(DISCORD_BOTS_TOKEN):
        Info.echo("Updating Stats")
        let client = newAsyncHttpClient()
        client.headers = newHttpHeaders({
                "User-Agent": "Light (1.1)",
                "Authorization": DISCORD_BOTS_TOKEN,
                "Content-Type": "application/json"
            })
        let serverCount = r.guilds.len()
        Debug.echo($serverCount)
        let requestBody = %*{"server_count": $serverCount}
        asyncCheck client.request(fmt"https://top.gg/api/bots/{r.user.id}/stats", httpMethod=HttpPost, body = $requestBody)

## test
proc updateStatMsg*(s: Shard) {.async.} =
    let messages = @[
        (gatPlaying, "chess"),
        (gatPlaying, "Corney in the house for the new 3ds"),
        (gatListening, "10 hours of main menu animal crossing theme song"),
        (gatPlaying, "basketball")
    ]
    while true:
        let message = sample(messages)
        await s.updateStatus(game = some GameStatus(
                    name: message[1],
                    kind: message[0]
                ))
        await sleepAsync(60 * 5 * 1000)

template Discord*(token: string, templateBody: untyped): untyped {.dirty.} =
    randomize(getTime().toUnix)
    cl = newDiscordClient(token)

    cl.events.on_ready = proc (s: Shard, r: Ready) {.async.} =
        # Run when bot connects to discord
        echo("Connected to Discord as " & $r.user)
        when defined(release): # Only update server count if running release version
            asyncCheck r.postStats

        let ownerUser = await cl.api.getUser(OWNER_USER_ID)
        echo $ownerUser  & " is my owner"
        let gatewayBot = await cl.api.getGatewayBot()
        echo(gatewayBot.session_start_limit.max_concurrency)
        asyncCheck updateStatMsg(s)

    cl.events.onDispatch = proc (s: Shard, evt: string, data: JsonNode) {.async.} =
        case evt:
        of "MESSAGE_CREATE":
            # If it is a message then check if there is something being awaited in the channel
            if waits.hasKey(data["channel_id"].str):
                let wait = waits[data["channel_id"].str]
                if wait.expected == data["author"]["id"].str:
                    wait.response.complete(data["content"].str)
                    waits.del(data["channel_id"].str)

        else:
            return

    cl.events.message_create = proc (s: Shard, m: Message) {.async.} =
        block:
            if m.author.bot:
                 break
            let message = m.clean()
            let sMessage = sentenceSound(message)
            let mentions = m.mention_users
            let isMentioned = mentions.anyIt(it.id == s.user.id)

            when not defined(release):
                echo("+--------------+")
                echo(isMentioned)
                echo(message)
                echo("+--------------+")
            try:
                genCommandStructure(templateBody)
                if ("help" in message and isMentioned) or message == "gimme help":
                    echo(helpMsg)
                    asyncCheck m.reply(helpMsg)
                    break

            except RestError: # Catch discord errors
                echo(getCurrentExceptionMsg())
            except:
                let
                    e = getCurrentException()
                    msg = getCurrentExceptionMsg()
                asyncCheck messageHome(fmt"Error {repr(e)}: {msg}")




    waitFor cl.startSession(guild_subscriptions = false)
