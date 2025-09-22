;; SupplyChainLedger - Product traceability and authenticity verification system

(define-map supply-chain-products uint {
  supplier: principal,
  product-identifier: (string-utf8 64),
  origin-details: (string-utf8 256),
  shipment-timestamp: uint,
  destination-facility: (string-utf8 64),
  authenticity-confirmed: bool
})

(define-map supplier-shipments principal (list 100 uint))
(define-map authenticity-validators principal bool)
(define-data-var product-tracking-id uint u0)

;; Error codes
(define-constant err-unauthorized-supplier (err u600))
(define-constant err-unauthorized-validator (err u601))
(define-constant err-product-not-tracked (err u602))
(define-constant err-access-denied-operation (err u403))
(define-constant err-shipment-capacity-exceeded (err u604))
(define-constant err-invalid-address-provided (err u605))
(define-constant err-empty-product-identifier (err u606))
(define-constant err-empty-origin-details (err u607))
(define-constant err-invalid-shipment-timestamp (err u608))
(define-constant err-empty-destination-facility (err u609))
(define-constant err-invalid-tracking-id (err u610))

;; Supply chain administrator
(define-constant supply-chain-admin tx-sender)

;; Register authenticity validator
(define-public (register-authenticity-validator (validator principal))
  (begin
    (asserts! (is-eq tx-sender supply-chain-admin) err-access-denied-operation)
    (asserts! (not (is-eq validator 'SP000000000000000000002Q6VF78)) err-invalid-address-provided)
    (ok (map-set authenticity-validators validator true))
  ))

;; Track product shipment
(define-public (track-product-shipment
  (product-identifier (string-utf8 64))
  (origin-details (string-utf8 256))
  (shipment-timestamp uint)
  (destination-facility (string-utf8 64)))
  (let
    ((tracking-id (var-get product-tracking-id))
     (supplier tx-sender)
     (current-shipments (default-to (list) (map-get? supplier-shipments supplier))))
    
    (asserts! (> (len product-identifier) u0) err-empty-product-identifier)
    (asserts! (> (len origin-details) u0) err-empty-origin-details)
    (asserts! (> shipment-timestamp u0) err-invalid-shipment-timestamp)
    (asserts! (> (len destination-facility) u0) err-empty-destination-facility)
    (asserts! (< (len current-shipments) u100) err-shipment-capacity-exceeded)
    
    (map-set supply-chain-products tracking-id {
      supplier: supplier,
      product-identifier: product-identifier,
      origin-details: origin-details,
      shipment-timestamp: shipment-timestamp,
      destination-facility: destination-facility,
      authenticity-confirmed: false
    })
    
    (let
      ((updated-shipments (unwrap-panic (as-max-len? (concat (list tracking-id) current-shipments) u100))))
      (map-set supplier-shipments supplier updated-shipments)
    )
    
    (var-set product-tracking-id (+ tracking-id u1))
    (ok tracking-id)))

;; Confirm product authenticity
(define-public (confirm-product-authenticity (tracking-id uint))
  (begin
    (asserts! (< tracking-id (var-get product-tracking-id)) err-invalid-tracking-id)
    (let
      ((product (unwrap! (map-get? supply-chain-products tracking-id) err-product-not-tracked)))
      (asserts! (default-to false (map-get? authenticity-validators tx-sender)) err-unauthorized-validator)
      (ok (map-set supply-chain-products tracking-id (merge product {authenticity-confirmed: true})))
    )
  ))

;; Get product tracking info
(define-read-only (get-product-tracking-info (tracking-id uint))
  (map-get? supply-chain-products tracking-id))

;; Get supplier shipments
(define-read-only (get-supplier-shipments (supplier principal))
  (default-to (list) (map-get? supplier-shipments supplier)))

;; Check validator status
(define-read-only (is-authenticity-validator (address principal))
  (default-to false (map-get? authenticity-validators address)))
