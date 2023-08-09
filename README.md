# Surefire

## How to use
Surefire is a package helping you write simple betting games that are somewhat "cost-aware".
Basic Money management is enforced by Surefire, aiming to minimize losses of the player over the long term.

To play with it, some examples are provided:
- `iex -S mix blackjack`

Because of Surefire's concerns, each game can be played multiple times, as in real life,
with an initial amount of credits. It is therefore possible to learn gameplay, discover game strategies, 
and adjust the amount of games to follow the basic "quitting while ahead" strategy as well.

## Concepts (WIP)

- **Avatar**: What is usually called a "player" in a game. That is the player who cares only about one game.
  It decides what to do at which time (prompted by the game), based on current game information only.
- **Player**: The strategic player, that owns credits and plays multiple games in a row, potentially learning over time...
- **Round**: What is usually called a "game". However this is limited to one instance of it, and it only involves **Avatars**, not players.
- **Game**: The long-running gmae, consisting of multiple similar rounds... Player's strategy is what that matters here.

## Features
 
INITIALLY: (WIP)
- a set of example games, fully functional via IEx. Multiple players can connect over multiple iex sessions to the same VM.
- a protocol/behaviour (TBD) to allow games to define their rules regarding profits/losses and player decisions
 
SOON:
- a protocol/behaviour (TBD) to allow games to integrate various User interfaces for player clients.
The original IEx interface being just one implementation of such a User Interface.

LATER:
- a protocol/behaviour (TBD) to allow games to optionally provide initial probabilities. 
Note they are also calculated/corrected during play sessions.
- a protocol/behaviour (TBD) to allow games to provide optimal strategies. 
Note discovering them over multiple gameplay is a somewhat very remote target, and will probably never happen...

Note: Surefire **will not** take care of writing automated players / AIs for these games. 
It might be a somewhat feasible goal once we have probabilities and strategies, but each game might want to provide a variety of these,
and making a generic one will be more troublesome than it is worth.
Therefore, these are expected to be part of the game code if needed.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `surefire` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:surefire, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/surefire>.

