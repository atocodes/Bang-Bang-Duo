# DotEnv for Godot

A lightweight Godot 4 addon that loads variables from a project-level `.env` file into the process environment.

## Requirements

- Godot 4.x

## Installation

1. Copy the `addons/dotenv` directory into your Godot project.
2. In Godot, open **Project > Project Settings > Plugins**.
3. Enable **DotEnv**.

Enabling the plugin registers `DotEnv` as an autoload singleton and adds `.env` to the project's `.gitignore`.

## Usage

Create a `.env` file in the project root:

```dotenv
# Service credentials
API_KEY="replace-with-your-key"
API_URL=https://api.example.com
DEBUG=true
```

Read a value from any script after the project starts:

```gdscript
var api_key := DotEnv.get_env("API_KEY")
var api_url := DotEnv.get_env("API_URL")
```

`DotEnv` reads `res://.env` when it enters the scene tree. Each valid `KEY=VALUE` line is passed to `OS.set_environment()`, and values can be retrieved with `DotEnv.get_env()` or `OS.get_environment()`.

## Supported `.env` Format

- Empty lines are ignored.
- Lines beginning with `#` are ignored.
- Values are split at the first `=` character, so values may contain additional `=` characters.
- Leading and trailing whitespace is removed from keys and values.
- Matching single or double quotes around a value are removed.

```dotenv
PLAIN_VALUE=hello
QUOTED_VALUE="hello world"
VALUE_WITH_EQUALS=first=second
```

## Security

Never commit real credentials or API keys. Keep `.env` ignored and provide setup instructions or a non-sensitive example file for collaborators instead. If a secret has been committed or shared, revoke and replace it with a new one.

## License

MIT License - see [LICENSE](LICENSE) for details
