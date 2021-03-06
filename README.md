## Haplo Documentation

[Documentation](https://support.haplo.com) for the [Haplo's commercial products](https://www.haplo.com/products)

## Editing the documentation

To set up:

* install `jruby`, make sure it's in your `PATH`
* run `jgem install RedCloth -v 4.2.9`
* check out the main [Haplo repository](https://github.com/haplo-org/haplo) at the same level as this repository

To preview your changes:

* run `script/doc-tool`
* visit `localhost:8899` in your browser.

Adding new files requires a restart, but otherwise click refresh to view your changes.

Before committing your changes, check all the files with:

`script/doc-tool check`

This ensures that all the documentation can be generated, in particular, that all the links point to a valid destination.

### Copyright

Haplo Documentation is copyright [Haplo Services Ltd](https://www.haplo-services.com). See the COPYRIGHT file for full details.
