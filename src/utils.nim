import times, os, math
import dimscord
import strutils
import logging
import httpclient
import asyncdispatch
import json
import macros

proc metricSecond(): int =
    let currentTime = now()
    let minutes = currentTime.minute
    let seconds = currentTime.second
    let temp = ((minutes * 60 + seconds)/100)
    return ((temp - floor(temp))*100).toInt()

proc toSeq*[T](args: varargs[T]): seq[T] =
    for arg in args:
        result &= arg

proc clean*(message: Message): string =
    result = message.stripMentions()        
    result = result.strip().toLowerAscii()

macro importAll*(directory: string): untyped =
    result = newStmtList()
    echo(directory.strVal)
    for kind, path in walkDir("src/" & directory.strVal):
        if kind == pcFile:
            result.add(nnkImportStmt.newTree(
                newIdentNode(path.replace(".nim", "").replace("src/", ""))
            ))

proc json*(response: AsyncResponse): Future[JsonNode] {.async.} = 
    return parseJson(await response.body)

if isMainModule:
    while true:
        echo metricSecond()
        sleep(1000)
