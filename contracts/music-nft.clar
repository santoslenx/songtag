;; Music NFT Contract
;; Handles NFT minting, metadata management, and ownership for music tracks
;; Supports collaborator management and royalty configuration

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-PERCENTAGE (err u400))
(define-constant ERR-INVALID-METADATA (err u411))
(define-constant ERR-TRANSFER-FAILED (err u412))
(define-constant ERR-INSUFFICIENT-BALANCE (err u413))
(define-constant ERR-INVALID-COLLABORATOR (err u414))

;; Data Variables
(define-data-var next-token-id uint u1)
(define-data-var total-supply uint u0)

;; NFT Definition
(define-non-fungible-token music-nft uint)

;; Music Track Metadata
(define-map music-metadata
  { token-id: uint }
  {
    title: (string-ascii 100),
    artist: (string-ascii 50),
    album: (optional (string-ascii 50)),
    genre: (string-ascii 30),
    duration: uint, ;; in seconds
    release-date: uint, ;; block height
    bpm: (optional uint),
    key-signature: (optional (string-ascii 10)),
    created-at: uint,
    ipfs-hash: (optional (string-ascii 64))
  }
)

;; Token Ownership and Creator Info
(define-map token-info
  { token-id: uint }
  {
    creator: principal,
    current-owner: principal,
    mint-price: uint,
    royalty-rate: uint, ;; percentage * 100 (e.g., 1000 = 10%)
    is-for-sale: bool,
    sale-price: (optional uint),
    total-collaborators: uint
  }
)

;; Collaborator Splits for each NFT
(define-map collaborator-splits
  { token-id: uint, collaborator: principal }
  {
    percentage: uint, ;; percentage * 100 (e.g., 2500 = 25%)
    role: (string-ascii 20), ;; "artist", "producer", "songwriter", etc.
    added-at: uint
  }
)

;; Track statistics
(define-map track-stats
  { token-id: uint }
  {
    total-plays: uint,
    total-earnings: uint,
    last-played: uint,
    play-count-today: uint
  }
)

;; Helper Functions

;; Get current block height as timestamp
(define-private (get-current-time)
  stacks-block-height
)

;; Validate percentage (must be between 0 and 10000, representing 0% to 100%)
(define-private (is-valid-percentage (percentage uint))
  (and (>= percentage u0) (<= percentage u10000))
)

;; Check if caller owns the NFT
(define-private (is-token-owner (token-id uint) (caller principal))
  (is-eq (some caller) (nft-get-owner? music-nft token-id))
)

;; Check if caller is the creator of the NFT
(define-private (is-token-creator (token-id uint) (caller principal))
  (match (map-get? token-info { token-id: token-id })
    info (is-eq caller (get creator info))
    false
  )
)

;; Validate metadata fields
(define-private (is-valid-metadata
    (title (string-ascii 100))
    (artist (string-ascii 50))
    (genre (string-ascii 30))
    (duration uint)
  )
  (and
    (> (len title) u0)
    (> (len artist) u0)
    (> (len genre) u0)
    (> duration u0)
  )
)

;; Public Functions

;; Mint a new music NFT with metadata and collaborators
(define-public (mint-music-nft
    (title (string-ascii 100))
    (artist (string-ascii 50))
    (album (optional (string-ascii 50)))
    (genre (string-ascii 30))
    (duration uint)
    (bpm (optional uint))
    (key-signature (optional (string-ascii 10)))
    (ipfs-hash (optional (string-ascii 64)))
    (mint-price uint)
    (royalty-rate uint)
    (to principal)
  )
  (let
    (
      (token-id (var-get next-token-id))
      (current-time (get-current-time))
    )
    ;; Validate inputs
    (asserts! (is-valid-metadata title artist genre duration) ERR-INVALID-METADATA)
    (asserts! (is-valid-percentage royalty-rate) ERR-INVALID-PERCENTAGE)
    
    ;; Mint the NFT
    (try! (nft-mint? music-nft token-id to))
    
    ;; Store metadata
    (map-set music-metadata
      { token-id: token-id }
      {
        title: title,
        artist: artist,
        album: album,
        genre: genre,
        duration: duration,
        release-date: current-time,
        bpm: bpm,
        key-signature: key-signature,
        created-at: current-time,
        ipfs-hash: ipfs-hash
      }
    )
    
    ;; Store token info
    (map-set token-info
      { token-id: token-id }
      {
        creator: tx-sender,
        current-owner: to,
        mint-price: mint-price,
        royalty-rate: royalty-rate,
        is-for-sale: false,
        sale-price: none,
        total-collaborators: u0
      }
    )
    
    ;; Initialize track stats
    (map-set track-stats
      { token-id: token-id }
      {
        total-plays: u0,
        total-earnings: u0,
        last-played: u0,
        play-count-today: u0
      }
    )
    
    ;; Update counters
    (var-set next-token-id (+ token-id u1))
    (var-set total-supply (+ (var-get total-supply) u1))
    
    (ok token-id)
  )
)

;; Add a collaborator to an existing NFT
(define-public (add-collaborator
    (token-id uint)
    (collaborator principal)
    (percentage uint)
    (role (string-ascii 20))
  )
  (let
    (
      (token-data (unwrap! (map-get? token-info { token-id: token-id }) ERR-NOT-FOUND))
      (current-time (get-current-time))
    )
    ;; Only creator can add collaborators
    (asserts! (is-token-creator token-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-percentage percentage) ERR-INVALID-PERCENTAGE)
    (asserts! (> (len role) u0) ERR-INVALID-METADATA)
    
    ;; Check if collaborator already exists
    (asserts! (is-none (map-get? collaborator-splits { token-id: token-id, collaborator: collaborator }))
              ERR-ALREADY-EXISTS)
    
    ;; Add collaborator
    (map-set collaborator-splits
      { token-id: token-id, collaborator: collaborator }
      {
        percentage: percentage,
        role: role,
        added-at: current-time
      }
    )
    
    ;; Update total collaborators count
    (map-set token-info
      { token-id: token-id }
      (merge token-data { total-collaborators: (+ (get total-collaborators token-data) u1) })
    )
    
    (ok true)
  )
)

;; Update track metadata (creator only)
(define-public (update-metadata
    (token-id uint)
    (title (string-ascii 100))
    (album (optional (string-ascii 50)))
    (ipfs-hash (optional (string-ascii 64)))
  )
  (let
    (
      (current-metadata (unwrap! (map-get? music-metadata { token-id: token-id }) ERR-NOT-FOUND))
    )
    ;; Only creator can update metadata
    (asserts! (is-token-creator token-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len title) u0) ERR-INVALID-METADATA)
    
    ;; Update metadata
    (map-set music-metadata
      { token-id: token-id }
      (merge current-metadata {
        title: title,
        album: album,
        ipfs-hash: ipfs-hash
      })
    )
    
    (ok true)
  )
)

;; Transfer NFT ownership
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-token-owner token-id sender) ERR-NOT-AUTHORIZED)
    
    ;; Transfer the NFT
    (try! (nft-transfer? music-nft token-id sender recipient))
    
    ;; Update owner in token-info
    (match (map-get? token-info { token-id: token-id })
      token-data (begin
                   (map-set token-info
                     { token-id: token-id }
                     (merge token-data { current-owner: recipient }))
                   true)
      false
    )
    
    (ok true)
  )
)

;; Set NFT for sale
(define-public (set-for-sale (token-id uint) (price uint))
  (let
    (
      (token-data (unwrap! (map-get? token-info { token-id: token-id }) ERR-NOT-FOUND))
    )
    ;; Only owner can set for sale
    (asserts! (is-token-owner token-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> price u0) ERR-INVALID-METADATA)
    
    ;; Update sale info
    (map-set token-info
      { token-id: token-id }
      (merge token-data {
        is-for-sale: true,
        sale-price: (some price)
      })
    )
    
    (ok true)
  )
)

;; Remove NFT from sale
(define-public (remove-from-sale (token-id uint))
  (let
    (
      (token-data (unwrap! (map-get? token-info { token-id: token-id }) ERR-NOT-FOUND))
    )
    ;; Only owner can remove from sale
    (asserts! (is-token-owner token-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Update sale info
    (map-set token-info
      { token-id: token-id }
      (merge token-data {
        is-for-sale: false,
        sale-price: none
      })
    )
    
    (ok true)
  )
)

;; Read-only Functions

;; Get music metadata for a token
(define-read-only (get-music-metadata (token-id uint))
  (map-get? music-metadata { token-id: token-id })
)

;; Get token info
(define-read-only (get-token-info (token-id uint))
  (map-get? token-info { token-id: token-id })
)

;; Get collaborator split info
(define-read-only (get-collaborator-split (token-id uint) (collaborator principal))
  (map-get? collaborator-splits { token-id: token-id, collaborator: collaborator })
)

;; Get track statistics
(define-read-only (get-track-stats (token-id uint))
  (map-get? track-stats { token-id: token-id })
)

;; Get next token ID
(define-read-only (get-next-token-id)
  (var-get next-token-id)
)

;; Get total supply
(define-read-only (get-total-supply)
  (var-get total-supply)
)

;; Get token owner
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? music-nft token-id))
)

;; Get token URI (placeholder - would link to metadata)
(define-read-only (get-token-uri (token-id uint))
  (ok none)
)

;; Check if token exists
(define-read-only (token-exists (token-id uint))
  (is-some (nft-get-owner? music-nft token-id))
)
