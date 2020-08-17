import dimscord
import httpclient
import asyncdispatch
import strutils
import ../utils
import ../discord
import uri
import sugar
import htmlparser, xmltree


proc define*(m: Message) {.async.} =
    let client = newAsyncHttpClient()
    let message = m.clean()
    let word = message.split("define", maxsplit=1)[1].strip()
    let response = await client.request("https://www.urbandictionary.com/define.php?term=" & encodeUrl(word), httpMethod=HttpGet)
    case response.code:
    of Http200:
        let page = parseHtml(await response.body)
        let allDivs = page.findAll("div")
        var WOTD = false # Is word of the day
        let definitions = collect(newSeq):
            for element in allDivs:
                # Finds the header element that gives the name
                # This is done to filter out word of the day definitions
                if element.attr("class") == "def-panel":
                    WOTD = false
                    for divElement in element.findAll("div"):
                        if divElement.attr("class") == "ribbon" and "Word of the Day" in divElement.innerText:
                            WOTD = true
                            break
                if element.attr("class") == "meaning" and not WOTD:
                    decodeUrl(element.innerText)    
        asyncCheck m.reply(sample(definitions))
    of Http404:
        asyncCheck m.reply(fmt"The definition of {word} is pretty weird, it's 'you are a fat idiot'")
    else:
        asyncCheck m.reply("Well you would look at that, urban dictionary is broke")
