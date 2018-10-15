# git-of-theseus.cr

Clone of [git-of-theseus](https://github.com/erikbern/git-of-theseus) in crystal lang.

## Installation

Download the [last release binary](https://github.com/smacker/git-of-theseus.cr/releases) or install it from master:

```
git clone https://github.com/smacker/git-of-theseus.cr.git
cd git-of-theseus.cr
crystal build --release src/git-of-theseus.cr
./git-of-theseus
```

## Usage

```
Usage: git-of-theseus.cr [repo]
    --interval=INT                   Min difference between commits to analyze (default: 604800)
    --outdir=PATH                    Output directory to store results (default: .)
    --branch=NAME                    Branch to track (default: refs/heads/master)
    -h, --help                       Show this help
```

It would generate json files compatible with plot generators of git-of-theseus.

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/smacker/git-of-theseus.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [smacker](https://github.com/smacker) Maxim Sukharev - creator, maintainer
