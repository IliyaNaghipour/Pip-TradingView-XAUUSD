# Ilia-trader

Pip XAUUSD indicator — all versions in one repository.

All TradingView Pine Script versions (v1 to v5.3), with MT5 MQL5 files where they exist for that version, each in its own folder.

## Versions

- `v1/` — fractals, EMA 50/200 trend, order blocks, 1-2-3, flags, alerts. Pine v5 + MT5.
- `v2/` — HTF trend filter, FVG, BOS/CHoCH, liquidity sweep, premium/discount, session filter, SL/TP, dashboard.
- `v3/` — TradingView-only, Persian interface, bug-checked.
- `v3.1/` — plotshape const-text fix, drawRisk global-variable fix.
- `v4/` — v4.0 Pine v6, OB scoring 0-100, 1-2-3 state machine, FVG, sessions + Kill Zones, backtest.
- `v4.1/` — CE10188 plot-in-local-scope fix.
- `v4.2/` — RE10045 empty-OB-array fix. First real TradingView compile success.
- `v4.3/` — backtest bug fixes (18 bugs).
- `v4.4/` — Pine v6 strategy.closedtrades fix.
- `v5.0/` — merged indicator + backtest, one OB/FVG/123 engine, 1000 lines.
- `v5.1/` — TP2/SL stats by exit comment.
- `v5.2/` — TP1 50% + TP2, pointvalue sizing, 1358 lines.
- `v5.3/` — 9-timeframe MTF engine, 8-condition entry, unique trade IDs, 2429 lines. Backtest: 1 trade total, Inconclusive.

## Notes

- Educational / development use. Not a trading signal, no profit guarantee.
- Latest version is v5.3. Older versions are kept untouched for history.
