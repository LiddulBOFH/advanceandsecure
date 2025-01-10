# Advance and Secure
> Fully fledged garry's mod gamemode that leans on ACF-3

[![A&S Discord](https://img.shields.io/discord/1113662258950705235?label=A%26S%20Discord&style=flat-square)](https://discord.gg/YDP72rfNgD)
[![ACF Discord](https://img.shields.io/discord/654142834030542878?label=ACF%20Discord&style=flat-square)](https://discord.gg/jgdzysxjST)
[![Steam Group](https://img.shields.io/badge/ACF%20Official-Join%20Now!-informational?style=flat-square)](https://steamcommunity.com/groups/officialacf)
[![Repository Size](https://img.shields.io/github/repo-size/ACF-Team/advanceandsecure?label=Repository%20Size&style=flat-square)](https://github.com/ACF-Team/advanceandsecure)
[![Commit Activity](https://img.shields.io/github/commit-activity/m/ACF-Team/advanceandsecure?label=Commit%20Activity&style=flat-square)](https://github.com/ACF-Team/advanceandsecure/graphs/commit-activity)

Similar to Squad's AAS/RAAS gamemode, each team must capture flags to start reducing the enemy's tickets to 0. Depending on flag status when captured, the capturing team will game tickets, and possibly reduce the enemy's tickets by an amount (if it was previously owned by them).

Each player has a resource known as Requisition, which is passively gained over time at a rate determined by map settings as well as how they have behaved throughout the match, as in karma. If they have been teamkilling or lingering around the enemy safezone, they will lose karma considerably. The only way to gain karma back is to do something productive for the team as a whole, which is to capture points.

Map setup is a breeze with a built-in STool which is only available to admins when the server is in editmode.

### Features

- [AdvDupe2](https://github.com/wiremod/advdupe2) distribution system (simply add files to distributables/advdupe2), allowing servers to provide dupes to players

- Cost calculator available as an E2, which is generated using the server's settings, and acquired which a simple click

### Integrations

- Has integration with another addon of mine, [BAdmin](https://github.com/LiddulBOFH/badmin)

### Usage

Simply clone into garrysmod/addons, and set the server to load "advanceandsecure" as the gamemode.
