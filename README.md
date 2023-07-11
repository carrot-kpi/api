<br />

<p align="center">
    <img src=".github/static/logo.svg" alt="Carrot logo" width="60%" />
</p>

<br />

<p align="center">
    Carrot is a web3 protocol trying to make incentivization easier and more capital
    efficient.
</p>

<br />

<p align="center">
    <img src="https://img.shields.io/badge/License-GPLv3-blue.svg" alt="License: GPL v3">
</p>

# Carrot API

This repository is a collection of projects used to implement the Carrot API in
full.

## Overview

There are 2 main parts to the API:

- Under the `./terraform` folder you can find the Terraform files used to
  bootstrap the needed infrastructure. Read the `README` under the folder to
  know more about that.
- Under the `./packages` folder you can find Javascript projects that implement
  some parts of the API. The main project to note there is the `pinning-proxy`.
  Under `./packages/pinning-proxy` you'll find a `README` with more information.
