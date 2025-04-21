# PropMatch: Fractional Real Estate Investment Platform

PropMatch is a decentralized application built on the Stacks blockchain that enables fractional ownership of real estate properties. This platform allows property owners to tokenize their real estate assets and sell shares to investors, who can then earn proportional revenue from rental income or property appreciation.

## Features

- **Property Tokenization**: Property owners can register their properties and divide ownership into shares
- **Share Purchase**: Investors can buy shares of properties using STX tokens
- **Revenue Distribution**: Automatic distribution of rental income to shareholders based on ownership percentage
- **Platform Fee**: Sustainable fee structure to maintain the platform

## Smart Contract

The PropMatch smart contract is written in Clarity and provides the core functionality for the platform:

### Data Structures

- `properties`: Stores information about registered properties
- `property-shares`: Tracks ownership shares for each investor
- `revenue-distributions`: Manages revenue distribution events

### Key Functions

- `register-property`: Allows property owners to tokenize their real estate
- `buy-shares`: Enables investors to purchase shares of a property
- `add-revenue`: Allows property owners to add rental income for distribution
- `distribute-revenue`: Processes the distribution of revenue
- `claim-revenue`: Allows shareholders to claim their portion of distributed revenue

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Clarity development environment
- [Stacks Wallet](https://www.hiro.so/wallet) - For interacting with the deployed contract

### Installation

1. Clone the repository