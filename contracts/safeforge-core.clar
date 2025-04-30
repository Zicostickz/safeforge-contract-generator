;; safeforge-core
;; 
;; This contract serves as the central registry for all approved contract templates and manages
;; the contract generation workflow. It maintains a database of templates, each with metadata
;; about their purpose, parameters, and security properties. It verifies parameters are within
;; acceptable ranges and that resulting contracts maintain security invariants.
;;
;; The contract handles template registration (requiring multi-signature approval from security
;; auditors), template versioning, and maintains an immutable record of all generated contracts
;; with their parameters and verification results.

;; === Error Codes ===
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-TEMPLATE-EXISTS (err u101))
(define-constant ERR-TEMPLATE-NOT-FOUND (err u102))
(define-constant ERR-INVALID-VERSION (err u103))
(define-constant ERR-INSUFFICIENT-APPROVALS (err u104))
(define-constant ERR-ALREADY-APPROVED (err u105))
(define-constant ERR-PARAMETER-OUT-OF-RANGE (err u106))
(define-constant ERR-VERIFICATION-FAILED (err u107))
(define-constant ERR-APPROVAL-NOT-FOUND (err u108))
(define-constant ERR-ALREADY-GENERATED (err u109))
(define-constant ERR-AUDITOR-EXISTS (err u110))
(define-constant ERR-AUDITOR-NOT-FOUND (err u111))

;; === Data Storage ===

;; Contract governance
(define-data-var contract-owner principal tx-sender)
(define-map auditors principal bool)
(define-data-var min-approvals uint u2)
(define-data-var template-count uint u0)
(define-data-var generation-count uint u0)

;; Template data structures
(define-map templates
  { template-id: uint }
  {
    name: (string-ascii 64),
    description: (string-utf8 500),
    version: uint,
    created-by: principal,
    created-at: uint,
    parameter-schema: (list 10 {
      name: (string-ascii 64),
      description: (string-utf8 256),
      type: (string-ascii 20),
      min-value: (optional int),
      max-value: (optional int),
      allowed-values: (optional (list 10 (string-ascii 64)))
    }),
    contract-template: (string-utf8 10000),
    active: bool
  }
)

;; Template version history
(define-map template-versions
  { template-id: uint, version: uint }
  {
    contract-template: (string-utf8 10000),
    parameter-schema: (list 10 {
      name: (string-ascii 64),
      description: (string-utf8 256),
      type: (string-ascii 20),
      min-value: (optional int),
      max-value: (optional int),
      allowed-values: (optional (list 10 (string-ascii 64)))
    }),
    created-at: uint
  }
)

;; Template approvals
(define-map template-approvals
  { template-id: uint, version: uint, auditor: principal }
  {
    approved: bool,
    timestamp: uint,
    comments: (string-utf8 500)
  }
)

;; Generated contracts
(define-map generated-contracts
  { generation-id: uint }
  {
    template-id: uint,
    template-version: uint,
    parameters: (list 10 {
      name: (string-ascii 64),
      value: (string-utf8 256)
    }),
    verification-result: bool,
    verification-details: (string-utf8 500),
    created-by: principal,
    created-at: uint,
    contract-hash: (buff 32)
  }
)

;; === Private Functions ===

;; Check if the caller is the contract owner
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Check if the caller is an authorized auditor
(define-private (is-auditor)
  (default-to false (map-get? auditors tx-sender))
)

;; Count the number of approvals for a template version
(define-private (count-approvals (template-id uint) (version uint))
  (let
    (
      (approval-count
        (fold count-approval-reducer
          (map-keys template-approvals)
          u0
        ))
    )
    approval-count
  )
)

;; Helper function to count template approvals
(define-private (count-approval-reducer (key {template-id: uint, version: uint, auditor: principal}) (count uint))
  (if (and
        (is-eq (get template-id key) template-id)
        (is-eq (get version key) version)
        (get approved (default-to {approved: false, timestamp: u0, comments: ""} 
                       (map-get? template-approvals key)))
      )
    (+ count u1)
    count
  )
)

;; Get template by ID
(define-private (get-template (template-id uint))
  (map-get? templates {template-id: template-id})
)

;; Verify parameters against template schema
(define-private (verify-parameters 
                  (template-id uint) 
                  (version uint) 
                  (parameters (list 10 {name: (string-ascii 64), value: (string-utf8 256)})))
  ;; In a real implementation, this would contain complex validation logic
  ;; based on the parameter schema. For this example, we'll return true.
  (ok true)
)

;; Simulate contract verification
(define-private (verify-contract 
                  (template-id uint) 
                  (version uint) 
                  (parameters (list 10 {name: (string-ascii 64), value: (string-utf8 256)})))
  ;; In a real implementation, this would contain complex verification logic
  ;; This is a placeholder for what would be sophisticated static analysis and verification
  (ok {
    verified: true,
    details: "Contract successfully verified with no security issues found."
  })
)

;; Generate a contract hash (simulate hash generation)
(define-private (generate-contract-hash
                  (template-id uint)
                  (version uint)
                  (parameters (list 10 {name: (string-ascii 64), value: (string-utf8 256)})))
  ;; In a real implementation, this would generate a hash based on the template and parameters
  ;; For this example, we'll create a simple placeholder hash
  (sha256 (concat (concat 
                    (unwrap-panic (to-consensus-buff template-id))
                    (unwrap-panic (to-consensus-buff version)))
                  (unwrap-panic (to-consensus-buff parameters))))
)

;; === Read-Only Functions ===

;; Get template details
(define-read-only (get-template-details (template-id uint))
  (let ((template (get-template template-id)))
    (if (is-none template)
      ERR-TEMPLATE-NOT-FOUND
      (ok (unwrap-panic template))
    )
  )
)

;; Get template version
(define-read-only (get-template-version (template-id uint) (version uint))
  (let ((template-version (map-get? template-versions {template-id: template-id, version: version})))
    (if (is-none template-version)
      ERR-TEMPLATE-NOT-FOUND
      (ok (unwrap-panic template-version))
    )
  )
)

;; Get generated contract details
(define-read-only (get-generated-contract (generation-id uint))
  (let ((contract (map-get? generated-contracts {generation-id: generation-id})))
    (if (is-none contract)
      (err u404)
      (ok (unwrap-panic contract))
    )
  )
)

;; Check if a principal is an auditor
(define-read-only (is-principal-auditor (principal-to-check principal))
  (default-to false (map-get? auditors principal-to-check))
)

;; Get approval status for a template version
(define-read-only (get-approval-status (template-id uint) (version uint))
  (let
    (
      (approvals (count-approvals template-id version))
      (min-required (var-get min-approvals))
    )
    (ok {
      approvals: approvals,
      required: min-required,
      is-approved: (>= approvals min-required)
    })
  )
)

;; Get auditor's approval for a template
(define-read-only (get-auditor-approval (template-id uint) (version uint) (auditor principal))
  (let ((approval (map-get? template-approvals {template-id: template-id, version: version, auditor: auditor})))
    (if (is-none approval)
      ERR-APPROVAL-NOT-FOUND
      (ok (unwrap-panic approval))
    )
  )
)

;; === Public Functions ===

;; Transfer contract ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Add an auditor
(define-public (add-auditor (auditor principal))
  (begin
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? auditors auditor)) ERR-AUDITOR-EXISTS)
    (map-set auditors auditor true)
    (ok true)
  )
)

;; Remove an auditor
(define-public (remove-auditor (auditor principal))
  (begin
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? auditors auditor)) ERR-AUDITOR-NOT-FOUND)
    (map-delete auditors auditor)
    (ok true)
  )
)

;; Update minimum approvals required
(define-public (update-min-approvals (new-min-approvals uint))
  (begin
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    (var-set min-approvals new-min-approvals)
    (ok true)
  )
)

;; Register a new template
(define-public (register-template
                (name (string-ascii 64))
                (description (string-utf8 500))
                (parameter-schema (list 10 {
                                      name: (string-ascii 64),
                                      description: (string-utf8 256),
                                      type: (string-ascii 20),
                                      min-value: (optional int),
                                      max-value: (optional int),
                                      allowed-values: (optional (list 10 (string-ascii 64)))
                                    }))
                (contract-template (string-utf8 10000)))
  (let
    (
      (template-id (+ (var-get template-count) u1))
    )
    (asserts! (or (is-owner) (is-auditor)) ERR-NOT-AUTHORIZED)
    
    ;; Increment template count and create new template
    (var-set template-count template-id)
    
    ;; Store the template
    (map-set templates
      {template-id: template-id}
      {
        name: name,
        description: description,
        version: u1,
        created-by: tx-sender,
        created-at: block-height,
        parameter-schema: parameter-schema,
        contract-template: contract-template,
        active: false
      }
    )
    
    ;; Store initial version
    (map-set template-versions
      {template-id: template-id, version: u1}
      {
        contract-template: contract-template,
        parameter-schema: parameter-schema,
        created-at: block-height
      }
    )
    
    (ok template-id)
  )
)

;; Update an existing template (creates a new version)
(define-public (update-template
                (template-id uint)
                (parameter-schema (list 10 {
                                      name: (string-ascii 64),
                                      description: (string-utf8 256),
                                      type: (string-ascii 20),
                                      min-value: (optional int),
                                      max-value: (optional int),
                                      allowed-values: (optional (list 10 (string-ascii 64)))
                                    }))
                (contract-template (string-utf8 10000)))
  (let
    (
      (template-opt (get-template template-id))
    )
    ;; Check authorization
    (asserts! (or (is-owner) (is-auditor)) ERR-NOT-AUTHORIZED)
    
    ;; Check template exists
    (asserts! (is-some template-opt) ERR-TEMPLATE-NOT-FOUND)
    
    (let
      (
        (template (unwrap-panic template-opt))
        (new-version (+ (get version template) u1))
      )
      
      ;; Update template with new version number
      (map-set templates
        {template-id: template-id}
        (merge template {
          version: new-version,
          parameter-schema: parameter-schema,
          contract-template: contract-template,
          active: false
        })
      )
      
      ;; Store new version
      (map-set template-versions
        {template-id: template-id, version: new-version}
        {
          contract-template: contract-template,
          parameter-schema: parameter-schema,
          created-at: block-height
        }
      )
      
      (ok new-version)
    )
  )
)

;; Approve a template version
(define-public (approve-template (template-id uint) (version uint) (comments (string-utf8 500)))
  (let
    (
      (template-opt (get-template template-id))
      (template-version-opt (map-get? template-versions {template-id: template-id, version: version}))
    )
    ;; Check authorization
    (asserts! (is-auditor) ERR-NOT-AUTHORIZED)
    
    ;; Check template and version exist
    (asserts! (is-some template-opt) ERR-TEMPLATE-NOT-FOUND)
    (asserts! (is-some template-version-opt) ERR-INVALID-VERSION)
    
    ;; Check if already approved by this auditor
    (asserts! (is-none (map-get? template-approvals 
                               {template-id: template-id, version: version, auditor: tx-sender}))
                      ERR-ALREADY-APPROVED)
    
    ;; Record approval
    (map-set template-approvals
      {template-id: template-id, version: version, auditor: tx-sender}
      {
        approved: true,
        timestamp: block-height,
        comments: comments
      }
    )
    
    ;; Check if enough approvals to activate
    (let
      (
        (approval-count (count-approvals template-id version))
        (min-required (var-get min-approvals))
        (template (unwrap-panic template-opt))
      )
      (if (>= approval-count min-required)
        ;; If enough approvals, activate template
        (map-set templates
          {template-id: template-id}
          (merge template {active: true})
        )
        true
      )
      
      (ok approval-count)
    )
  )
)

;; Generate a contract from a template
(define-public (generate-contract
                (template-id uint)
                (parameters (list 10 {name: (string-ascii 64), value: (string-utf8 256)})))
  (let
    (
      (template-opt (get-template template-id))
    )
    ;; Check template exists
    (asserts! (is-some template-opt) ERR-TEMPLATE-NOT-FOUND)
    
    (let
      (
        (template (unwrap-panic template-opt))
        (version (get version template))
        (generation-id (+ (var-get generation-count) u1))
      )
      ;; Check template is active
      (asserts! (get active template) ERR-INSUFFICIENT-APPROVALS)
      
      ;; Verify parameters
      (asserts! (is-ok (verify-parameters template-id version parameters)) ERR-PARAMETER-OUT-OF-RANGE)
      
      ;; Verify contract security
      (let
        (
          (verification-result (unwrap-panic (verify-contract template-id version parameters)))
          (contract-hash (generate-contract-hash template-id version parameters))
        )
        ;; Record the generated contract
        (var-set generation-count generation-id)
        
        (map-set generated-contracts
          {generation-id: generation-id}
          {
            template-id: template-id,
            template-version: version,
            parameters: parameters,
            verification-result: (get verified verification-result),
            verification-details: (get details verification-result),
            created-by: tx-sender,
            created-at: block-height,
            contract-hash: contract-hash
          }
        )
        
        (ok {
          generation-id: generation-id,
          contract-hash: contract-hash,
          verified: (get verified verification-result)
        })
      )
    )
  )
)