### Monto Disintegrated Development Environment

This package allows you to use Atom with other components from the [Monto
Disintegrated Development Environment](https://bitbucket.org/inkytonik/monto).

#### Author

inkytonik, Anthony Sloane ([inkytonik@gmail.com](mailto:inkytonik@gmail.com))

### Overview

The Monto architecture consists of background *server processes* that listen for versions of files to be published by *source processes*.
In response to version messages, servers asynchronously respond with *products* that contain some derived information (e.g., an outline view).
Products are consumed by *client processes* that typically display the information to a user.
Communication between sources, servers and clients is facilitated by a single broker process.
A more detailed description of the Monto architecture can be found on the [Monto project wiki](https://bitbucket.org/inkytonik/monto/src/default/wiki/architecture.md).

This package allows Atom to play the role of source and client in the Monto architecture.
Each time a change is made to a file in the editor the package publishes a version of that file.
The editor user can use the package to create product views that display products as they arrive.

### Running a Monto broker and servers

The easiest way to run a Monto broker and associated servers is to use the [reference Python implementation](https://bitbucket.org/inkytonik/monto/src/default/wiki/python.md) which contains a simple management script.
Please refer to the reference implementation instructions for details on how to install that implementation and configure it.

The reference implementation includes some simple sources and servers that can be useful for experimentation.

We assume in the following that you are successfully running the Monto broker and at least the "reflect" server that simply bounces version messages back as products.

### Specifying products you wish to use

Monto products are identified by names such as "reflect".
Since the choice of products is highly user-specific and typing them in manually is error-prone, the package has a "Product List" setting in which you can specify a comma-separated list of the names of the products you wish to use.
The setting is used to populate a list from which you can choose when creating a product view (see below).

By default, the setting contains some products used by the reference Monto implementation (including the "reflect" product) so you can use it as-is for testing.
Once you are familiar with using this package you should adjust the setting so it contains the products you wish to use.

### Creating textual product views

You can create product views in Atom using the `Monto: Open Text View` command (bound to `alt-m v` by default).
This command displays a list of the products that you have listed in the "Product List" setting and allows you to select from the list in the same manner as the main Atom command palette.

Selecting a product causes a view on that product to be created in a pane next to the active editor.
When messages containing that product arrive the content of the message will be displayed in the product view.

For example, try running a broker with the "reflect" server and then create a "reflect" product view.
You will then be able to edit any file and see the changes to those files reflected in the product.

### Creating HTML product views

The `Monto: Open HTML View` command (bound to `alt-m h` by default) can be used to create a HTML product view.
Such a view will display a product written in language "html" as the rendered HTML.
For example, if you are running the "reflect" server you can open a HTML view on the "reflect" product, then edit a `.html` file to see the rendered HTML of the file in the product view as you edit.
