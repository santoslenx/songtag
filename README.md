# Songtag - NFT Music Royalties Contract

A blockchain-based NFT music royalties system that automatically splits payments across collaborators using smart contracts on the Stacks blockchain.

## Overview

Songtag provides a transparent, automated solution for music creators to mint their works as NFTs and automatically distribute royalties among all collaborators. The system ensures fair compensation through immutable smart contracts and provides real-time tracking of earnings and distributions.

## Features

### 🎵 **Music NFT Management**
- Mint unique music tracks as Non-Fungible Tokens
- Store comprehensive metadata including title, artist, genre, and duration
- Set royalty rates and define collaborator splits
- Track ownership and transfer history

### 💰 **Automated Royalty Distribution**
- Smart contract-based payment splitting
- Real-time royalty calculations
- Automatic distribution to all collaborators
- Transparent earnings tracking
- Support for multiple revenue streams

### 👥 **Multi-Collaborator Support**
- Define unlimited collaborators per track
- Flexible percentage-based splits
- Support for artists, producers, songwriters, and other contributors
- Individual earning statements and history

### 🔒 **Ownership & Rights Management**
- Immutable ownership records on blockchain
- Transfer and licensing capabilities
- Creator verification and attribution
- Rights management for sampling and remixes

## Smart Contracts

### 1. Music NFT Contract (`music-nft.clar`)
Core NFT functionality for music tracks:
- Token minting and metadata management
- Ownership tracking and transfers
- Music-specific attributes (duration, genre, BPM)
- Royalty rate configuration
- Creator and collaborator definitions

### 2. Royalty Splitter Contract (`royalty-splitter.clar`)
Handles automatic payment distribution:
- Revenue collection and tracking
- Percentage-based split calculations
- Automated payments to collaborators
- Earnings history and statements
- Withdrawal mechanisms

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Music         │    │   Music NFT     │    │   Royalty       │
│   Creators      │───▶│   Contract      │───▶│   Splitter      │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   Stacks        │
                       │   Blockchain    │
                       └─────────────────┘
```

## Usage

### For Artists & Creators
1. Mint your music track as an NFT with metadata
2. Define all collaborators and their percentage splits
3. Set royalty rates for different usage types
4. Track earnings and distributions in real-time
5. Transfer or license NFT ownership as needed

### For Collaborators
1. Receive automatic notifications of new collaborations
2. Monitor earnings from all collaborative works
3. Withdraw accumulated royalties
4. View detailed payment history and statements

### For Music Industry
1. Transparent royalty management
2. Automated rights clearance
3. Immutable ownership records
4. Efficient payment distribution
5. Reduced administrative overhead

## Technical Specifications

### Blockchain: Stacks
### Smart Contract Language: Clarity
### Development Framework: Clarinet
### Testing: Vitest with TypeScript

## Project Structure

```
songtag/
├── contracts/
│   ├── music-nft.clar           # Music NFT implementation
│   └── royalty-splitter.clar    # Payment distribution system
├── tests/
│   ├── music-nft_test.ts        # NFT contract tests
│   └── royalty-splitter_test.ts # Royalty system tests
├── settings/
│   ├── Devnet.toml             # Development network settings
│   ├── Testnet.toml            # Testnet configuration
│   └── Mainnet.toml            # Mainnet configuration
├── Clarinet.toml               # Project configuration
├── package.json                # Node.js dependencies
└── README.md                   # This file
```

## Development Setup

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) installed
- [Node.js](https://nodejs.org/) (v16 or higher)
- [Git](https://git-scm.com/)

### Installation
```bash
# Clone the repository
git clone <repository-url>
cd songtag

# Install dependencies
npm install

# Run tests
npm test

# Check contract syntax
clarinet check
```

## Core Features

### Music NFT Creation
```clarity
;; Mint a new music NFT with metadata and collaborator splits
(mint-music-nft 
  title 
  artist 
  duration 
  genre 
  royalty-rate 
  collaborators)
```

### Royalty Distribution
```clarity
;; Distribute royalties based on predefined splits
(distribute-royalties nft-id amount)

;; Withdraw accumulated earnings
(withdraw-earnings collaborator-address)
```

### Metadata Management
```clarity
;; Get comprehensive NFT metadata
(get-music-metadata nft-id)

;; Update NFT information (creator only)
(update-metadata nft-id new-metadata)
```

## Use Cases

Perfect for:
- Independent artists and music creators
- Record labels and music distributors
- Collaborative music projects
- Music NFT marketplaces
- Streaming platform integrations
- Rights management organizations

## Revenue Streams

The system supports various revenue sources:
- **Primary Sales**: Initial NFT purchases
- **Secondary Sales**: Resale commissions
- **Streaming Royalties**: Platform streaming revenue
- **Licensing Fees**: Commercial usage rights
- **Sync Licensing**: Film/TV/advertising placements

## Security Features

- **Immutable Contracts**: Tamper-proof payment logic
- **Automated Distribution**: Eliminates manual payment errors
- **Transparent Tracking**: All transactions publicly verifiable
- **Multi-signature Support**: Enhanced security for high-value NFTs
- **Access Control**: Creator-only functions for sensitive operations

## Testing

The project includes comprehensive tests covering:
- NFT minting and metadata management
- Royalty calculation and distribution
- Collaborator management and payments
- Ownership transfers and licensing
- Error handling and edge cases

Run tests with:
```bash
npm test
```

## Deployment

### Development Network
```bash
clarinet integrate
```

### Testnet Deployment
```bash
clarinet deploy --testnet
```

### Mainnet Deployment
```bash
clarinet deploy --mainnet
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests for new functionality
4. Ensure all tests pass with `clarinet check`
5. Submit a pull request

## License

This project is open-source and available under the MIT License.

## Support

For questions, issues, or contributions, please open an issue in the GitHub repository.

---

**Songtag** - Revolutionizing music royalties through blockchain transparency and automated distribution.
