# Engine

Owns the local engine boundary.

- `Transport`: engine process lifecycle, RPC dispatch, and stream handling.
- `Models`: engine request and response models.
- `Support`: contracts, protocol helpers, and engine-specific path logic.

Keep engine-facing serialization details inside this domain.
