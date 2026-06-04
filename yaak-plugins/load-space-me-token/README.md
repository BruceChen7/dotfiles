# load-space-me-token

Yaak plugin that reads the SPACE platform token from `~/.space/token` and exposes it as
the `${[me_token()]}` template function.

## Usage

After installing this plugin, use `${[me_token()]}` in any Yaak template field
(URL, headers, body, etc.) to inject your SPACE token.

This does not write to Yaak's environment variable store. Yaak calls the template
function while rendering the request, then uses the returned token value.

### Example

```
Authorization: Bearer ${[me_token()]}
```

## How it works

The plugin defines a template function `me_token` that reads `~/.space/token`
on every render. If the file doesn't exist, can't be read, or contains only
whitespace, it returns empty.
