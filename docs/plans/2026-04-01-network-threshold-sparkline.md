# Network Threshold Sparkline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve the AI network threshold chart so the default threshold presets are visible and large peaks do not flatten the whole sparkline.

**Architecture:** Introduce a small chart presentation model that converts raw hourly KB samples into a stable logarithmic chart scale, then update the menu bar sparkline card to render threshold guide ticks and the new scale label.

**Tech Stack:** Swift, SwiftUI, Swift Testing

---

### Task 1: Add a chart presentation model

**Files:**
- Create: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/MonitoredTrafficChartPresentation.swift`
- Test: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/MonitoredTrafficChartPresentationTests.swift`

### Task 2: Update the sparkline card

**Files:**
- Modify: `/Users/gaoshizai/work/ai_power/Sources/AIPowerApp/MenuBarView.swift`
- Test: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/MonitoredTrafficChartPresentationTests.swift`

### Task 3: Verify behavior

**Files:**
- Test: `/Users/gaoshizai/work/ai_power/Tests/AIPowerAppTests/MonitoredTrafficChartPresentationTests.swift`

