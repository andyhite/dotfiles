# tree-sitter

> Command-line interface for the tree-sitter incremental parsing library.
> Used to develop, test, and query tree-sitter grammars, and by editors (Neovim, Zed) for syntax highlighting support.
> More information: <https://github.com/tree-sitter/tree-sitter>.

- Parse a file and print its syntax tree:

`tree-sitter parse {{path/to/file}}`

- Regenerate a parser's C sources from its `grammar.js`:

`tree-sitter generate`

- Run a parser's test corpus:

`tree-sitter test`

- Compile a parser to a loadable shared library:

`tree-sitter build`

- Print syntax highlighting for a file, using the grammar's highlight queries:

`tree-sitter highlight {{path/to/file}}`

- Start an interactive playground in the browser for the grammar in the current directory:

`tree-sitter playground`
