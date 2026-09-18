# Examples

`INDEX.json` is the list: every entry says what it **does**, what it needs on
disk, and the command.

```bash
cat examples/INDEX.json
```

## Here, now

Both of these run with nothing but `npm install`.

```bash
scripts/rgr run examples/hello/Hello.rgr    # a class, a main, a line of output
npm run example:calc                        # a recursive-descent parser
```

`Calc.rgr` is worth the two minutes: a tokenizer and a recursive-descent parser
in one file, and the same source as three languages —

```bash
scripts/rgr run examples/calc/Calc.rgr
scripts/rgr run examples/calc/Calc.rgr -l=python
scripts/rgr run examples/calc/Calc.rgr -l=go
```

Python prints `7.0` where the other two print `7`. That is not a bug in the
example; it is the reason its `toNumber` trims before `to_double`, and the
reason tests here compare values rather than printed strings. `to_double` takes
`"10 "` in JavaScript and Python and refuses it in Go, so the untrimmed version
of that function returned the right answer on two targets and zero on the
third — from one source, which is the one thing Ranger promises not to do.

## In the gallery

The rest of the index — a PDF with no browser in it, Markdown to PowerPoint,
diagrams from Mermaid and D2, Vega charts, a Figma reader, a spreadsheet, an
application — lives in the Ranger repository. EVG itself, the layout engine
under `lib/evg`, is **MIT**; the applications under `gallery/` are
**AGPL-3.0-or-later** rather than MIT. Each entry's `add` field is the command:

```bash
scripts/add-gallery.sh          # what can be added, and what it costs
scripts/add-gallery.sh evg      # MIT
scripts/add-gallery.sh rave     # AGPL — it says so before adding
```

Read [the license note](../README.md#the-gallery-and-the-license-line) first.
