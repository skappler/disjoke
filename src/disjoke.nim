import reddit
import asyncdispatch
import discord
import utils
import config
importAll("commands") # Imports all the command files

# Init other services
asyncCheck getPostsService()


const apiKey = if not defined(release): DEBUG_DISCORD_TOKEN else: DISCORD_TOKEN

Discord(apiKey):
    Command("report", mentioned=true, exact=false):
        ## Send a report to my owner (Be descriptive or I'll beat you)
        await messageHome(message.replace("report", "**report**:"))

    Command("define", mentioned=true, exact=false):
        ## Defines a word from a reputable site known as Urban Dictionary
        await define(m)

    Command("or", mentioned=true, exact=false):
        # Chooses between two options (yes I know this command is hidden)
        let options = message.strip().split(" or ")
        discard await m.reply(sample(options))

    command("movie", mentioned=true, exact=false):
        ## Returns info for a movie. Info is from The Movie Database 🎥
        await searchTmdb(m, true)

    command("tv", mentioned=true, exact=false):
        ## Returns info for a TV show. Info is from The Movie Database 📺
        await searchTmdb(m, false)

    command("fuck", "bitch", "cunt", "bastard", "cringe", "fat", "asswipe", mentioned=true, exact=false, soundex=true):
        # Defends himself
        let possibleResponses {.global.} = [
            "Shut up fatty",
            "No, I'm stuff",
            "Look at you champ, insulting a bunch of 1's and 0's",
            "My penis has more inches than you have brain cells",
            "Your IQ is room temperature",
            "AAAAAAAAAAAAAHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH",
            "https://cdn.discordapp.com/attachments/296056831514509312/740797968575234079/video0.mp4",
            "https://tenor.com/view/shut-up-nerd-american-flag-football-gif-14505499",
            "https://cdn.discordapp.com/attachments/296056831514509312/740799549362405456/video0.mp4"
        ]
        discard await m.reply(sample(possibleResponses))
    
