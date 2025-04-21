;; PropMatch: Fractional Real Estate Investment Platform
;; This contract manages property tokenization, ownership, and revenue distribution

;; Error codes
(define-constant err-unauthorized (err u1))
(define-constant err-property-exists (err u2))
(define-constant err-property-not-found (err u3))
(define-constant err-insufficient-funds (err u4))
(define-constant err-sold-out (err u5))
(define-constant err-transfer-failed (err u6))
(define-constant err-invalid-amount (err u7))

;; Data structures
(define-map properties
  { property-id: uint }
  {
    name: (string-ascii 100),
    location: (string-ascii 100),
    total-shares: uint,
    available-shares: uint,
    price-per-share: uint,
    total-revenue: uint,
    owner: principal
  }
)

(define-map property-shares
  { property-id: uint, owner: principal }
  { shares: uint }
)

(define-map revenue-distributions
  { distribution-id: uint }
  {
    property-id: uint,
    amount: uint,
    distribution-date: uint,
    completed: bool
  }
)

;; Variables
(define-data-var next-property-id uint u1)
(define-data-var next-distribution-id uint u1)
(define-data-var platform-fee-percent uint u2) ;; 2% platform fee

;; Read-only functions
(define-read-only (get-property (property-id uint))
  (map-get? properties { property-id: property-id })
)

(define-read-only (get-shares (property-id uint) (owner principal))
  (default-to { shares: u0 }
    (map-get? property-shares { property-id: property-id, owner: owner })
  )
)

(define-read-only (get-distribution (distribution-id uint))
  (map-get? revenue-distributions { distribution-id: distribution-id })
)

(define-read-only (calculate-share-value (property-id uint) (share-count uint))
  (let (
    (property (unwrap-panic (get-property property-id)))
    (price-per-share (get price-per-share property))
  )
    (* price-per-share share-count)
  )
)

;; Public functions
(define-public (register-property (name (string-ascii 100)) (location (string-ascii 100)) (total-shares uint) (price-per-share uint))
  (let (
    (property-id (var-get next-property-id))
    (caller tx-sender)
  )
    ;; Check that total shares is greater than zero
    (asserts! (> total-shares u0) err-invalid-amount)
    
    ;; Check that price per share is greater than zero
    (asserts! (> price-per-share u0) err-invalid-amount)
    
    ;; Add the property to the map
    (map-set properties
      { property-id: property-id }
      {
        name: name,
        location: location,
        total-shares: total-shares,
        available-shares: total-shares,
        price-per-share: price-per-share,
        total-revenue: u0,
        owner: caller
      }
    )
    
    ;; Increment the property ID counter
    (var-set next-property-id (+ property-id u1))
    
    ;; Return the new property ID
    (ok property-id)
  )
)

(define-public (buy-shares (property-id uint) (share-count uint))
  (let (
    (property (unwrap-panic (get-property property-id)))
    (available-shares (get available-shares property))
    (price-per-share (get price-per-share property))
    (property-owner (get owner property))
    (total-cost (* price-per-share share-count))
    (caller tx-sender)
    (current-shares (get shares (get-shares property-id caller)))
  )
    ;; Check that there are enough shares available
    (asserts! (>= available-shares share-count) err-sold-out)
    
    ;; Transfer the STX from the buyer to the property owner
    (asserts! (>= (stx-get-balance caller) total-cost) err-insufficient-funds)
    (try! (stx-transfer? total-cost caller property-owner))
    
    ;; Update the property's available shares
    (map-set properties
      { property-id: property-id }
      (merge property { available-shares: (- available-shares share-count) })
    )
    
    ;; Update the buyer's shares
    (map-set property-shares
      { property-id: property-id, owner: caller }
      { shares: (+ current-shares share-count) }
    )
    
    (ok true)
  )
)

(define-public (add-revenue (property-id uint) (amount uint))
  (let (
    (property (unwrap-panic (get-property property-id)))
    (caller tx-sender)
    (property-owner (get owner property))
    (current-revenue (get total-revenue property))
  )
    ;; Only the property owner can add revenue
    (asserts! (is-eq caller property-owner) err-unauthorized)
    
    ;; Transfer the STX from the caller to the contract
    (try! (stx-transfer? amount caller (as-contract tx-sender)))
    
    ;; Update the property's total revenue
    (map-set properties
      { property-id: property-id }
      (merge property { total-revenue: (+ current-revenue amount) })
    )
    
    ;; Create a new distribution
    (let (
      (distribution-id (var-get next-distribution-id))
    )
      (map-set revenue-distributions
        { distribution-id: distribution-id }
        {
          property-id: property-id,
          amount: amount,
          distribution-date: block-height,
          completed: false
        }
      )
      
      ;; Increment the distribution ID counter
      (var-set next-distribution-id (+ distribution-id u1))
      
      (ok distribution-id)
    )
  )
)

(define-public (distribute-revenue (distribution-id uint))
  (let (
    (distribution (unwrap-panic (get-distribution distribution-id)))
    (property-id (get property-id distribution))
    (amount (get amount distribution))
    (completed (get completed distribution))
    (property (unwrap-panic (get-property property-id)))
    (total-shares (get total-shares property))
    (platform-fee (/ (* amount (var-get platform-fee-percent)) u100))
    (distributable-amount (- amount platform-fee))
  )
    ;; Check that the distribution hasn't already been completed
    (asserts! (not completed) err-unauthorized)
    
    ;; Mark the distribution as completed
    (map-set revenue-distributions
      { distribution-id: distribution-id }
      (merge distribution { completed: true })
    )
    
    (ok true)
  )
)

(define-public (claim-revenue (property-id uint) (distribution-id uint))
  (let (
    (distribution (unwrap-panic (get-distribution distribution-id)))
    (distribution-property-id (get property-id distribution))
    (amount (get amount distribution))
    (completed (get completed distribution))
    (property (unwrap-panic (get-property property-id)))
    (total-shares (get total-shares property))
    (caller tx-sender)
    (investor-shares (get shares (get-shares property-id caller)))
    (platform-fee (/ (* amount (var-get platform-fee-percent)) u100))
    (distributable-amount (- amount platform-fee))
    (investor-share (/ (* distributable-amount investor-shares) total-shares))
  )
    ;; Check that the property IDs match
    (asserts! (is-eq property-id distribution-property-id) err-property-not-found)
    
    ;; Check that the investor has shares
    (asserts! (> investor-shares u0) err-unauthorized)
    
    ;; Check that the distribution is completed
    (asserts! completed err-unauthorized)
    
    ;; Transfer the investor's share of the revenue
    (as-contract (stx-transfer? investor-share tx-sender caller))
  )
)

(define-public (set-platform-fee (new-fee-percent uint))
  (begin
    ;; Only the contract deployer can set the platform fee
    (asserts! (is-eq tx-sender (contract-caller)) err-unauthorized)
    
    ;; Fee cannot be more than 10%
    (asserts! (<= new-fee-percent u10) err-invalid-amount)
    
    (var-set platform-fee-percent new-fee-percent)
    (ok true)
  )
)