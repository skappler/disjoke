import asyncdispatch, dimscord
import sequtils
export sequtils
import strformat
import strutils
export strutils
import options
import soundex
import logging
import sugar
export sugar
import random
export random
import reddit
export dimscord
import macros
import json
export json
export macros

var cl*: DiscordClient

const ownerUserID*: string = "259999449995018240"

proc reply*(message: Message, body: string, embed: Option[Embed] = none(
        Embed)): Future[Message] {.async.} =
    Debug.echo("replying with: " & body)
    return await cl.api.sendMessage(message.channelId, body, embed = embed)

template Command*(matches: varargs[string], mentioned: bool = false,
        exact: bool = true, body: untyped): untyped {.dirty.} =
    body
    break

proc sentenceSound*(input: string): string =
    for word in input.split(" "):
        result &= soundex(word)

proc clean*(message: Message): string =
    result = message.content
    for mentioned in message.mention_users:
        result = result.replace(fmt"<@!{mentioned.id}>", "")
    result = result.strip()


proc messageHome*(body: string) {.async.} =
    let owner = await cl.api.createUserDm(ownerUserID)
    asyncCheck cl.api.sendMessage(owner.id, body)

macro genCommandStructure*(body: untyped): untyped =
    # Create the reddit commands
    var redditTree = newStmtList()
    for index in 0..<len(subreddits):
        let subreddit = subreddits[index]
        var commandTree = newTree(nnkStmtList)
        let commandBody = newTree(nnkStmtList, newCommentStmtNode(
                "Gets posts from the subreddit r/" & subreddit.subreddit))
        commandBody.add(
            newNimnode(nnkVarSection).add(
                # Gets the subreddit at the specified index, saves having to redeclare it
            newIdentDefs(newIdentNode("sub"), newEmptyNode(),
                    nnkBracketExpr.newTree(newIdentNode("subreddits"), newLit(
                    index))),
            newIdentDefs(newidentNode("post"), newEmptynode(), newCall(
                    "getPost", newidentnode("sub")))))
        commandBody.add(newTree(nnkDiscardStmt, nnkCommand.newTree(newIdentNode(
                "asyncCheck"), newCall("reply", newIdentNode("m"),
        nnkDotExpr.newTree(
            newIdentNode("post"),
             newIdentNode("body")
        ),
        nnkDotExpr.newTree(
              newIdentNode("post"),
              newIdentNode("embed")
            )
        ))))
        commandTree.add(newStrLitNode("gimme " & subreddit.command))
        commandTree.add(commandBody)
        body.add(commandTree)
    result = newStmtList()

    # Create generic text commands
    let generalCommands = parseJson(readFile(
            "src/commands.json")) # Have to use this instead cause parseFile doesn't work at compile time
    echo pretty(generalCommands)
    for commandNode in generalCommands["generalResponses"].pairs:
        var commandBody = newStmtList()
        let strCommand = commandNode.val.getStr()
        if strCommand != "":
            commandBody.add(nnkCommand.newTree(newIdentNode("asyncCheck"),
                    newCall("reply", newIdentNode("m"), newLit(strCommand))))
        else:
            var responsesTree = nnkBracket.newTree()
            for item in commandNode.val.getElems():
                responsesTree.add(newLit(item.getStr()))
            commandBody.add(nnkCommand.newTree(newIdentNode("asyncCheck"),
                    newCall("reply", newIdentNode("m"), newCall("sample",
                    responsesTree))))
        body.add(newStmtList(newStrLitNode(commandNode.key), commandBody))

    var helpMessage = ""

    var mentionedCaseTree = newTree(nnkCaseStmt, newIdentNode("message"))
    var mentionedExtraTree = newStmtList()

    var generalCaseTree = newTree(nnkCaseStmt, newIdentNode("message"))
    for commandNode in body:
        var commandTree = newStmtList()
        var commandNames: seq[string]
        var commandSound = ""
        # Parameters of the template Command are used here to be known later
        var mentioned = false
        var exact = true

        for paramNode in commandNode:
            ## Finds all the values specified for the command
            case paramNode.kind:
            of nnkStrLit:
                commandNames.add(paramNode.strVal)

            of nnkExprEqExpr:
                echo(astGenRepr(paramNode))
                # I know .boolVal exists, but it doesn't work
                case paramNode[0].strVal:
                of "mentioned": mentioned = paramNode[1].strVal == "true"
                of "exact": exact = paramNode[1].strVal == "true"

            of nnkStmtList:
                for n in paramNode:
                    if n.kind == nnkCommentStmt: ## Finds the comment
                        helpMessage &= "**" & commandNames.join(", ") &
                                "**:\\n\\t" & n.strVal.replace("\n",
                                "\\n").replace("\\n", "\\n\\t") & "\\n"
                        break

                # Adds all the different ways of saying the command
                var newOfBranch = nnkOfBranch.newTree()
                for command in commandNames:
                    newOfBranch.add(newLit(command))
                newOfBranch.add(paramNode)
                # Checks which branch to add it to
                echo(commandNames[0], exact, mentioned)
                if mentioned and exact:
                    mentionedCaseTree.add(newOfBranch)
                elif mentioned and not exact:
                    mentionedExtraTree.add(
                        newIfStmt((
                        nnkInfix.newTree(
                            newIdentNode("in"),
                            newLit(commandNames[0]), # TODO allow different stuff
                        newIdentNode("message")
                    ), paramNode))
                    )
                else:
                    generalCaseTree.add(newOfBranch)
            else:
                continue

    result.add(parseStmt("let helpMsg = " & '"' & helpMessage & '"'))

    # Add the inexact commands onto the else path of the case statement
    mentionedCaseTree.add(nnkElse.newTree(mentionedExtraTree))

    var mentionedIfStmt = newIfStmt(
        (ident("isMentioned"), mentionedCaseTree)
        )
    mentionedIfStmt.add(newTree(nnkElse, generalCaseTree))
    result.add(mentionedIfStmt)
    echo(astGenRepr(result))

template Discord*(token: string, body: untyped): untyped {.dirty.} =
    randomize()
    cl = newDiscordClient(token)

    cl.events.on_ready = proc (s: Shard, r: Ready) {.async.} =
        # Run when bot connects to discord
        echo "Connected to Discord as " & $r.user
        let ownerUser = await cl.api.getUser(ownerUserID)
        echo $ownerUser & " is my owner"
        when not defined(debug):
            asyncCheck messageHome("I am running")


    cl.events.message_create = proc (s: Shard, m: Message) {.async.} =
        block:
            let message = m.clean()
            let mentions = m.mention_users
            let isMentioned = mentions.anyIt(it.id == s.user.id)
            if m.author.bot:
                break

            when defined(debug):
                echo("+--------------+")
                echo(isMentioned)
                # echo(message, sentenceSound(message))
                echo(message)
                echo("+--------------+")

            genCommandStructure(body)

            if ("help" in message and isMentioned) or message == "gimme help":
                echo(helpMsg)
                asyncCheck m.reply(helpMsg)
                break



    waitFor cl.startSession(compress = false)
