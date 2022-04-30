# Move Program Kit (MPK)

The Move Program Kit (MPK) is a collection of software written in the [Move programming language](https://move-book.com/) for the [Aptos](https://aptoslabs.com) blockchain.

## Modules

- **MPK20** - Lightweight token standard.

## Developing

First, install the [Move CLI](https://github.com/move-language/move) for Aptos via:

```
cargo install --git https://github.com/move-language/move --locked  --force move-cli --features address32
```

To build the software, run:

```
move package build
```

## License

Apache 2.0.
