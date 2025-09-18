;; Royalty Splitter Contract
;; Handles automatic payment distribution among music collaborators
;; Manages earnings, withdrawals, and payment history

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-INSUFFICIENT-BALANCE (err u403))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-TRANSFER-FAILED (err u405))
(define-constant ERR-ALREADY-DISTRIBUTED (err u409))
(define-constant ERR-NO-EARNINGS (err u410))
(define-constant ERR-INVALID-TOKEN (err u411))
(define-constant ERR-ZERO-COLLABORATORS (err u412))

;; Platform fee (1% = 100)
(define-constant PLATFORM-FEE u100)

;; Data Variables
(define-data-var total-revenue uint u0)
(define-data-var platform-earnings uint u0)
(define-data-var next-payment-id uint u1)

;; Revenue tracking for each NFT
(define-map nft-revenue
  { token-id: uint }
  {
    total-received: uint,
    total-distributed: uint,
    pending-distribution: uint,
    last-distribution: uint,
    distribution-count: uint
  }
)

;; Individual earnings for each collaborator per NFT
(define-map collaborator-earnings
  { token-id: uint, collaborator: principal }
  {
    total-earned: uint,
    total-withdrawn: uint,
    pending-withdrawal: uint,
    last-payment: uint,
    payment-count: uint
  }
)

;; Payment history
(define-map payment-history
  { payment-id: uint }
  {
    token-id: uint,
    recipient: principal,
    amount: uint,
    payment-type: (string-ascii 20), ;; "royalty", "sale", "streaming"
    timestamp: uint,
    transaction-hash: (optional (buff 32))
  }
)

;; Revenue sources tracking
(define-map revenue-sources
  { token-id: uint, source: (string-ascii 30) }
  {
    total-amount: uint,
    payment-count: uint,
    last-payment: uint
  }
)

;; Collaborator withdrawal requests
(define-map withdrawal-requests
  { collaborator: principal, token-id: uint }
  {
    requested-amount: uint,
    request-time: uint,
    status: (string-ascii 20) ;; "pending", "approved", "rejected"
  }
)

;; Helper Functions

;; Get current block height as timestamp
(define-private (get-current-time)
  stacks-block-height
)

;; Calculate platform fee
(define-private (calculate-platform-fee (amount uint))
  (/ (* amount PLATFORM-FEE) u10000)
)

;; Calculate net amount after platform fee
(define-private (calculate-net-amount (amount uint))
  (- amount (calculate-platform-fee amount))
)

;; Validate amount is greater than zero
(define-private (is-valid-amount (amount uint))
  (> amount u0)
)

;; Get next payment ID and increment
(define-private (get-and-increment-payment-id)
  (let ((current-id (var-get next-payment-id)))
    (var-set next-payment-id (+ current-id u1))
    current-id
  )
)

;; Calculate collaborator share based on percentage
(define-private (calculate-collaborator-share (amount uint) (percentage uint))
  (/ (* amount percentage) u10000)
)

;; Public Functions

;; Receive revenue for a specific NFT
(define-public (receive-revenue
    (token-id uint)
    (amount uint)
    (source (string-ascii 30)) ;; "streaming", "sale", "licensing", etc.
  )
  (let
    (
      (current-time (get-current-time))
      (platform-fee (calculate-platform-fee amount))
      (net-amount (calculate-net-amount amount))
      (current-revenue (default-to
                         { total-received: u0, total-distributed: u0, pending-distribution: u0, 
                           last-distribution: u0, distribution-count: u0 }
                         (map-get? nft-revenue { token-id: token-id })))
    )
    ;; Validate amount
    (asserts! (is-valid-amount amount) ERR-INVALID-AMOUNT)
    
    ;; Update NFT revenue tracking
    (map-set nft-revenue
      { token-id: token-id }
      {
        total-received: (+ (get total-received current-revenue) amount),
        total-distributed: (get total-distributed current-revenue),
        pending-distribution: (+ (get pending-distribution current-revenue) net-amount),
        last-distribution: (get last-distribution current-revenue),
        distribution-count: (get distribution-count current-revenue)
      }
    )
    
    ;; Update revenue source tracking
    (match (map-get? revenue-sources { token-id: token-id, source: source })
      source-data (map-set revenue-sources
                    { token-id: token-id, source: source }
                    {
                      total-amount: (+ (get total-amount source-data) amount),
                      payment-count: (+ (get payment-count source-data) u1),
                      last-payment: current-time
                    })
      ;; Initialize if first payment from this source
      (map-set revenue-sources
        { token-id: token-id, source: source }
        {
          total-amount: amount,
          payment-count: u1,
          last-payment: current-time
        })
    )
    
    ;; Update global tracking
    (var-set total-revenue (+ (var-get total-revenue) amount))
    (var-set platform-earnings (+ (var-get platform-earnings) platform-fee))
    
    (ok net-amount)
  )
)

;; Distribute pending royalties to all collaborators of an NFT
(define-public (distribute-royalties (token-id uint) (collaborators (list 20 { collaborator: principal, percentage: uint })))
  (let
    (
      (current-time (get-current-time))
      (revenue-data (unwrap! (map-get? nft-revenue { token-id: token-id }) ERR-NOT-FOUND))
      (pending-amount (get pending-distribution revenue-data))
    )
    ;; Validate there are pending distributions
    (asserts! (> pending-amount u0) ERR-NO-EARNINGS)
    (asserts! (> (len collaborators) u0) ERR-ZERO-COLLABORATORS)
    
    ;; Distribute to each collaborator
    (try! (fold distribute-to-collaborator 
                collaborators 
                (ok { token-id: token-id, total-amount: pending-amount, timestamp: current-time })))
    
    ;; Update NFT revenue tracking
    (map-set nft-revenue
      { token-id: token-id }
      {
        total-received: (get total-received revenue-data),
        total-distributed: (+ (get total-distributed revenue-data) pending-amount),
        pending-distribution: u0,
        last-distribution: current-time,
        distribution-count: (+ (get distribution-count revenue-data) u1)
      }
    )
    
    (ok pending-amount)
  )
)

;; Helper function for distributing to a single collaborator
(define-private (distribute-to-collaborator 
    (collaborator-info { collaborator: principal, percentage: uint })
    (context-result (response { token-id: uint, total-amount: uint, timestamp: uint } uint))
  )
  (match context-result
    context 
      (let
        (
          (token-id (get token-id context))
          (total-amount (get total-amount context))
          (timestamp (get timestamp context))
          (collaborator (get collaborator collaborator-info))
          (percentage (get percentage collaborator-info))
          (share-amount (calculate-collaborator-share total-amount percentage))
          (payment-id (get-and-increment-payment-id))
          (current-earnings (default-to
                              { total-earned: u0, total-withdrawn: u0, pending-withdrawal: u0, 
                                last-payment: u0, payment-count: u0 }
                              (map-get? collaborator-earnings { token-id: token-id, collaborator: collaborator })))
        )
        ;; Update collaborator earnings
        (map-set collaborator-earnings
          { token-id: token-id, collaborator: collaborator }
          {
            total-earned: (+ (get total-earned current-earnings) share-amount),
            total-withdrawn: (get total-withdrawn current-earnings),
            pending-withdrawal: (+ (get pending-withdrawal current-earnings) share-amount),
            last-payment: timestamp,
            payment-count: (+ (get payment-count current-earnings) u1)
          }
        )
        
        ;; Record payment history
        (map-set payment-history
          { payment-id: payment-id }
          {
            token-id: token-id,
            recipient: collaborator,
            amount: share-amount,
            payment-type: "royalty",
            timestamp: timestamp,
            transaction-hash: none
          }
        )
        
        (ok context)
      )
    error (err error)
  )
)

;; Withdraw earnings for a collaborator
(define-public (withdraw-earnings (token-id uint) (amount uint))
  (let
    (
      (current-time (get-current-time))
      (earnings-data (unwrap! (map-get? collaborator-earnings { token-id: token-id, collaborator: tx-sender }) ERR-NOT-FOUND))
      (available-amount (get pending-withdrawal earnings-data))
      (payment-id (get-and-increment-payment-id))
    )
    ;; Validate withdrawal amount
    (asserts! (is-valid-amount amount) ERR-INVALID-AMOUNT)
    (asserts! (<= amount available-amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer STX to collaborator
    (try! (stx-transfer? amount (as-contract tx-sender) tx-sender))
    
    ;; Update earnings
    (map-set collaborator-earnings
      { token-id: token-id, collaborator: tx-sender }
      {
        total-earned: (get total-earned earnings-data),
        total-withdrawn: (+ (get total-withdrawn earnings-data) amount),
        pending-withdrawal: (- (get pending-withdrawal earnings-data) amount),
        last-payment: (get last-payment earnings-data),
        payment-count: (get payment-count earnings-data)
      }
    )
    
    ;; Record withdrawal in payment history
    (map-set payment-history
      { payment-id: payment-id }
      {
        token-id: token-id,
        recipient: tx-sender,
        amount: amount,
        payment-type: "withdrawal",
        timestamp: current-time,
        transaction-hash: none
      }
    )
    
    (ok amount)
  )
)

;; Withdraw all available earnings for a collaborator
(define-public (withdraw-all-earnings (token-id uint))
  (let
    (
      (earnings-data (unwrap! (map-get? collaborator-earnings { token-id: token-id, collaborator: tx-sender }) ERR-NOT-FOUND))
      (available-amount (get pending-withdrawal earnings-data))
    )
    ;; Check if there are earnings to withdraw
    (asserts! (> available-amount u0) ERR-NO-EARNINGS)
    
    ;; Withdraw all available earnings
    (withdraw-earnings token-id available-amount)
  )
)

;; Emergency withdraw for contract owner
(define-public (emergency-withdraw (amount uint) (recipient principal))
  (begin
    ;; Only contract owner can perform emergency withdrawal
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-amount amount) ERR-INVALID-AMOUNT)
    
    ;; Transfer STX
    (try! (stx-transfer? amount (as-contract tx-sender) recipient))
    
    (ok amount)
  )
)

;; Read-only Functions

;; Get NFT revenue information
(define-read-only (get-nft-revenue (token-id uint))
  (map-get? nft-revenue { token-id: token-id })
)

;; Get collaborator earnings
(define-read-only (get-collaborator-earnings (token-id uint) (collaborator principal))
  (map-get? collaborator-earnings { token-id: token-id, collaborator: collaborator })
)

;; Get payment history entry
(define-read-only (get-payment-history (payment-id uint))
  (map-get? payment-history { payment-id: payment-id })
)

;; Get revenue source information
(define-read-only (get-revenue-source (token-id uint) (source (string-ascii 30)))
  (map-get? revenue-sources { token-id: token-id, source: source })
)

;; Get withdrawal request
(define-read-only (get-withdrawal-request (collaborator principal) (token-id uint))
  (map-get? withdrawal-requests { collaborator: collaborator, token-id: token-id })
)

;; Get total platform revenue
(define-read-only (get-total-revenue)
  (var-get total-revenue)
)

;; Get platform earnings
(define-read-only (get-platform-earnings)
  (var-get platform-earnings)
)

;; Get next payment ID
(define-read-only (get-next-payment-id)
  (var-get next-payment-id)
)

;; Get contract balance
(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

;; Calculate potential earnings for a collaborator
(define-read-only (calculate-earnings (amount uint) (percentage uint))
  (calculate-collaborator-share amount percentage)
)
