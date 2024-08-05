# PR Template

[ref : solady](https://github.com/Vectorized/solady/issues/19)

## Emoji key for Issues and PRs

Format: `<emoji><space><Title>`

| Type             | Emoji |
| ---------------- | ----- |
| readme/docs      | 📝    |
| new feature      | ✨    |
| refactor/cleanup | ♻️    |
| nit              | 🥢    |
| security fix     | 🔒    |
| optimization     | ⚡️   |
| configuration    | 👷‍♂️    |
| events           | 🔊    |
| bug fix          | 🐞    |

## Styling

1. Underscore prefix are reserved for private and internal functions.
2. Variables and code expressions in comments should be backquoted (e.g. `b`).
3. Memory addresses and memory related constants should be in hexadecimal format (e.g. 0x20). This is to convey semantic meaning, and aid readability for binary / hexadecimal natives.
4. Please keep the maximum line length, including comments to 100 characters or below. This is a balance between the old-school 80 character limit and the newer 120 character limit in the Solidity style guide. This makes it easier to read code on small or split screens.
