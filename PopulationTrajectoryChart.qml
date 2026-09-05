import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property var countryData: null
  property string selectedYear: "2026"
  signal yearSelected(string year)

  property int hoveredYear: -1
  property real hoveredPop: -1
  property bool isHovered: false
  property bool showChangeColumns: true

  readonly property var trajectory: (countryData && countryData.trajectory) ? countryData.trajectory : []
  readonly property bool isSubReplacement: countryData ? (countryData.isSubReplacement === true) : true
  readonly property real tfr: countryData ? countryData.tfr : 2.1
  readonly property int startYear: 1950
  readonly property int endYear: countryData ? (countryData.trajectoryEndYear || (isSubReplacement ? 2150 : 2126)) : 2126

  // Find maximum population in trajectory to scale Y-axis
  readonly property real maxPop: {
    if (!trajectory || trajectory.length === 0) return 100.0
    var m = 0.0
    for (var i = 0; i < trajectory.length; i++) {
      if (trajectory[i].pop > m) m = trajectory[i].pop
    }
    return Math.max(m * 1.18, 1.0)
  }

  implicitWidth: Style.space(912)
  implicitHeight: Style.space(165)

  function formatPop(val) {
    if (val === undefined || val === null || isNaN(val)) return "--"
    if (val >= 1000) return (val / 1000).toFixed(2) + "B"
    if (val < 0.1 && val > 0) return "<0.1M"
    return val.toFixed(1) + "M"
  }

  function getX(year, plotWidth, marginX) {
    var totalYears = Math.max(1, root.endYear - root.startYear)
    var frac = Math.max(0, Math.min(1, (year - root.startYear) / totalYears))
    return marginX + frac * plotWidth
  }

  function getY(pop, plotHeight, marginY) {
    var frac = Math.max(0, Math.min(1, pop / root.maxPop))
    return marginY + (1.0 - frac) * plotHeight
  }

  function findPointForMouse(mouseX, plotWidth, marginX) {
    if (!trajectory || trajectory.length === 0) return null
    var totalYears = Math.max(1, root.endYear - root.startYear)
    var rawYear = root.startYear + ((mouseX - marginX) / plotWidth) * totalYears
    var closest = trajectory[0]
    var minDiff = 9999
    for (var i = 0; i < trajectory.length; i++) {
      var diff = Math.abs(trajectory[i].year - rawYear)
      if (diff < minDiff) {
        minDiff = diff
        closest = trajectory[i]
      }
    }
    return closest
  }

  function getRateData(targetYear) {
    if (!trajectory || trajectory.length < 2) return null
    var idx = -1
    for (var i = 0; i < trajectory.length; i++) {
      if (trajectory[i].year === targetYear) {
        idx = i
        break
      }
    }
    if (idx < 0) {
      var minD = 9999
      for (var j = 0; j < trajectory.length; j++) {
        var d = Math.abs(trajectory[j].year - targetYear)
        if (d < minD) {
          minD = d
          idx = j
        }
      }
    }
    if (idx < 0) return null

    var cur = trajectory[idx]
    var prev = idx > 0 ? trajectory[idx - 1] : cur
    var next = idx < trajectory.length - 1 ? trajectory[idx + 1] : cur

    var dt = 0
    var dp = 0
    if (idx > 0) {
      dt = cur.year - prev.year
      dp = cur.pop - prev.pop
    } else if (idx < trajectory.length - 1) {
      dt = next.year - cur.year
      dp = next.pop - cur.pop
    }

    var netAnnual = dt !== 0 ? (dp / dt) : 0.0
    var pctAnnual = cur.pop > 0 ? ((netAnnual / cur.pop) * 100.0) : 0.0
    var pop2026 = root.countryData ? (root.countryData.population2026 || cur.pop) : cur.pop
    var delta2026 = cur.pop - pop2026

    return {
      year: cur.year,
      pop: cur.pop,
      netAnnual: netAnnual,
      pctAnnual: pctAnnual,
      delta2026: delta2026
    }
  }

  readonly property int activeYear: (root.isHovered && root.hoveredYear > 0) ? root.hoveredYear : parseInt(root.selectedYear, 10)
  readonly property var activeRate: getRateData(activeYear)

  onCountryDataChanged: canvas.requestPaint()
  onSelectedYearChanged: canvas.requestPaint()
  onShowChangeColumnsChanged: canvas.requestPaint()

  Column {
    anchors.fill: parent
    spacing: Style.space(4)

    // Chart Title, Legend & Subtitle Badge
    Item {
      width: parent.width
      height: Style.space(18)

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.isSubReplacement
          ? "📉 TRAJECTORY & PATH TO ZERO (TFR " + root.tfr.toFixed(2) + ")"
          : "📈 100Y GROWTH TRAJECTORY (TFR " + root.tfr.toFixed(2) + ")"
        color: root.isSubReplacement ? "#f87171" : "#4ade80"
        font.family: Style.font.family
        font.pixelSize: 9
        font.bold: true
      }

      // Center Milestone Legend & Column Toggle
      Row {
        anchors.centerIn: parent
        spacing: Style.space(8)
        visible: root.isSubReplacement

        Row {
          spacing: 3
          Rectangle { width: 7; height: 7; radius: 3.5; color: "#fbbf24"; border.color: "#000"; border.width: 1; anchors.verticalCenter: parent.verticalCenter }
          Text { text: "Peak"; color: Color.muted; font.pixelSize: 8; font.family: Style.font.family; anchors.verticalCenter: parent.verticalCenter }
        }

        Row {
          spacing: 3
          Rectangle { width: 7; height: 7; radius: 3.5; color: "#f43f5e"; border.color: "#000"; border.width: 1; anchors.verticalCenter: parent.verticalCenter }
          Text { text: "T½ Halving (50%)"; color: Color.muted; font.pixelSize: 8; font.family: Style.font.family; anchors.verticalCenter: parent.verticalCenter }
        }

        Row {
          spacing: 3
          Rectangle { width: 7; height: 7; radius: 3.5; color: "#dc2626"; border.color: "#fff"; border.width: 1; anchors.verticalCenter: parent.verticalCenter }
          Text { text: "Zero (~0)"; color: Color.muted; font.pixelSize: 8; font.family: Style.font.family; anchors.verticalCenter: parent.verticalCenter }
        }

        // Clickable Option A Toggle
        MouseArea {
          width: colToggleRow.implicitWidth + 8
          height: 14
          anchors.verticalCenter: parent.verticalCenter
          cursorShape: Qt.PointingHandCursor
          onClicked: root.showChangeColumns = !root.showChangeColumns

          Rectangle {
            anchors.fill: parent
            radius: 3
            color: root.showChangeColumns ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            border.color: root.showChangeColumns ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
            border.width: 1
          }

          Row {
            id: colToggleRow
            anchors.centerIn: parent
            spacing: 3
            Rectangle { width: 3; height: 8; radius: 1; color: "#4ade80"; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 3; height: 8; radius: 1; color: "#f87171"; anchors.verticalCenter: parent.verticalCenter }
            Text {
              text: root.showChangeColumns ? "Δ Columns: ON" : "Δ Columns: OFF"
              color: root.showChangeColumns ? Color.foreground : Color.muted
              font.pixelSize: 8
              font.family: Style.font.family
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }

      // Right: Active Year & Live Reduction / Growth Info
      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(5)

        // Year & Population
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.activeRate ? ("Yr " + root.activeRate.year + ": " + root.formatPop(root.activeRate.pop)) : ("Yr " + root.selectedYear)
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: 8
          font.bold: true
        }

        // Live Rate Pill (Growth / Reduction)
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          visible: root.activeRate !== null
          height: Style.space(14)
          width: rateBadgeText.implicitWidth + Style.space(8)
          radius: 3
          color: {
            if (!root.activeRate) return "transparent"
            if (Math.abs(root.activeRate.netAnnual) < 0.005) return Qt.rgba(0.98, 0.75, 0.14, 0.15)
            if (root.activeRate.netAnnual < 0) return Qt.rgba(0.97, 0.44, 0.44, 0.15)
            return Qt.rgba(0.29, 0.87, 0.50, 0.15)
          }
          border.color: {
            if (!root.activeRate) return "transparent"
            if (Math.abs(root.activeRate.netAnnual) < 0.005) return Qt.rgba(0.98, 0.75, 0.14, 0.4)
            if (root.activeRate.netAnnual < 0) return Qt.rgba(0.97, 0.44, 0.44, 0.4)
            return Qt.rgba(0.29, 0.87, 0.50, 0.4)
          }
          border.width: 1

          Text {
            id: rateBadgeText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            font.family: Style.font.family
            font.pixelSize: 8
            font.bold: true
            color: {
              if (!root.activeRate) return Color.muted
              if (Math.abs(root.activeRate.netAnnual) < 0.005) return "#fbbf24"
              if (root.activeRate.netAnnual < 0) return "#f87171"
              return "#4ade80"
            }
            text: {
              if (!root.activeRate) return ""
              if (Math.abs(root.activeRate.netAnnual) < 0.005) {
                return (root.countryData && root.activeRate.year === root.countryData.peakYear) ? "⏸ Peak Crest" : "⏸ 0/yr (0.00%)"
              }
              var arrow = root.activeRate.netAnnual < 0 ? "🔻 " : "🔺 +"
              var sign = root.activeRate.netAnnual < 0 ? "" : "+"
              var netStr = Math.abs(root.activeRate.netAnnual) < 1.0
                ? Math.round(root.activeRate.netAnnual * 1000) + "k/yr"
                : root.activeRate.netAnnual.toFixed(2) + "M/yr"
              return arrow + netStr + " (" + sign + root.activeRate.pctAnnual.toFixed(2) + "%/yr)"
            }
          }
        }

        // Delta vs 2026 Anchor
        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: root.activeRate !== null && root.activeRate.year !== 2026
          font.family: Style.font.family
          font.pixelSize: 7
          color: Color.muted
          textFormat: Text.PlainText
          text: {
            if (!root.activeRate || root.activeRate.year === 2026) return ""
            var d = root.activeRate.delta2026
            var s = d > 0 ? "+" : ""
            var str = Math.abs(d) < 1.0 ? Math.round(d * 1000) + "k" : d.toFixed(1) + "M"
            return "[" + s + str + " vs '26]"
          }
        }
      }
    }

    // Canvas Line Chart
    Rectangle {
      width: parent.width
      height: Style.space(136)
      color: Qt.rgba(0.06, 0.09, 0.14, 0.95)
      border.color: Qt.rgba(1, 1, 1, 0.1)
      border.width: 1
      radius: 6
      clip: true

      Canvas {
        id: canvas
        anchors.fill: parent
        anchors.margins: 2
        renderTarget: Canvas.FramebufferObject

        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)

          if (!root.countryData || !root.trajectory || root.trajectory.length === 0) return

          var marginL = 40
          var marginR = 24
          var marginT = 16
          var marginB = 24
          var plotW = width - marginL - marginR
          var plotH = height - marginT - marginB

          // 1. Grid Lines & Y-axis labels
          ctx.lineWidth = 1
          ctx.strokeStyle = "rgba(255, 255, 255, 0.07)"
          ctx.fillStyle = "#8892b0"
          ctx.font = "9px monospace"
          ctx.textAlign = "right"
          ctx.textBaseline = "middle"

          // 3 Y-grid lines
          for (var g = 0; g <= 3; g++) {
            var gridVal = (root.maxPop / 3.0) * g
            var yPos = root.getY(gridVal, plotH, marginT)
            ctx.beginPath()
            ctx.moveTo(marginL, yPos)
            ctx.lineTo(marginL + plotW, yPos)
            ctx.stroke()
            ctx.fillText(root.formatPop(gridVal), marginL - 6, yPos)
          }

          // X-axis baseline
          ctx.beginPath()
          ctx.strokeStyle = "rgba(255, 255, 255, 0.15)"
          ctx.moveTo(marginL, marginT + plotH)
          ctx.lineTo(marginL + plotW, marginT + plotH)
          ctx.stroke()

          // X-axis milestone labels
          ctx.textAlign = "center"
          ctx.textBaseline = "top"
          var xLabels = [1950, 2000, 2026]
          if (root.isSubReplacement && root.countryData) {
            if (root.countryData.peakYear > 2026) xLabels.push(root.countryData.peakYear)
            if (root.countryData.halvingYear) xLabels.push(root.countryData.halvingYear)
            if (root.countryData.extinctionYear) xLabels.push(root.countryData.extinctionYear)
            var stepCen = (root.endYear - 2026 > 600) ? 200 : 100
            for (var cen = 2100; cen < root.endYear - 50; cen += stepCen) {
              xLabels.push(cen)
            }
          } else {
            xLabels.push(2050, 2080, root.endYear)
          }

          xLabels.sort(function(a, b) { return a - b })

          var lastLabelX = -999
          for (var xi = 0; xi < xLabels.length; xi++) {
            var lx = root.getX(xLabels[xi], plotW, marginL)
            if (lx - lastLabelX >= 40 && (plotW + marginL - lx) >= 12) {
              ctx.fillText(String(xLabels[xi]), lx, marginT + plotH + 5)
              lastLabelX = lx
            }
          }

          // 2. Vertical 2026 divider (History vs Projection)
          var x2026 = root.getX(2026, plotW, marginL)
          ctx.beginPath()
          ctx.setLineDash([3, 3])
          ctx.strokeStyle = "rgba(255, 255, 255, 0.3)"
          ctx.moveTo(x2026, marginT)
          ctx.lineTo(x2026, marginT + plotH)
          ctx.stroke()
          ctx.setLineDash([])

          // Label: History | Projection
          ctx.font = "8px monospace"
          ctx.fillStyle = "rgba(56, 189, 248, 0.7)"
          ctx.textAlign = "right"
          ctx.fillText("◀ HISTORY", x2026 - 4, marginT + 2)

          ctx.fillStyle = root.isSubReplacement ? "rgba(248, 113, 113, 0.8)" : "rgba(74, 222, 128, 0.8)"
          ctx.textAlign = "left"
          ctx.fillText(root.isSubReplacement ? "PATH TO ZERO ▶" : "+100Y GROWTH ▶", x2026 + 4, marginT + 2)

          // 3. Fill Gradient Area Under Curve
          var histPts = []
          var futPts = []
          for (var p = 0; p < root.trajectory.length; p++) {
            var pt = root.trajectory[p]
            var px = root.getX(pt.year, plotW, marginL)
            var py = root.getY(pt.pop, plotH, marginT)
            if (pt.year <= 2026) histPts.push({ x: px, y: py })
            if (pt.year >= 2026) futPts.push({ x: px, y: py })
          }

          // Historical Area Fill
          if (histPts.length > 1) {
            ctx.beginPath()
            ctx.moveTo(histPts[0].x, marginT + plotH)
            for (var h = 0; h < histPts.length; h++) ctx.lineTo(histPts[h].x, histPts[h].y)
            ctx.lineTo(histPts[histPts.length - 1].x, marginT + plotH)
            ctx.closePath()
            var hGrad = ctx.createLinearGradient(0, marginT, 0, marginT + plotH)
            hGrad.addColorStop(0, "rgba(56, 189, 248, 0.25)")
            hGrad.addColorStop(1, "rgba(56, 189, 248, 0.0)")
            ctx.fillStyle = hGrad
            ctx.fill()
          }

          // Future Area Fill
          if (futPts.length > 1) {
            ctx.beginPath()
            ctx.moveTo(futPts[0].x, marginT + plotH)
            for (var f = 0; f < futPts.length; f++) ctx.lineTo(futPts[f].x, futPts[f].y)
            ctx.lineTo(futPts[futPts.length - 1].x, marginT + plotH)
            ctx.closePath()
            var fGrad = ctx.createLinearGradient(0, marginT, 0, marginT + plotH)
            if (root.isSubReplacement) {
              fGrad.addColorStop(0, "rgba(248, 113, 113, 0.25)")
              fGrad.addColorStop(1, "rgba(239, 68, 68, 0.0)")
            } else {
              fGrad.addColorStop(0, "rgba(74, 222, 128, 0.25)")
              fGrad.addColorStop(1, "rgba(74, 222, 128, 0.0)")
            }
            ctx.fillStyle = fGrad
            ctx.fill()
          }

          // Option A: Net Change Columns (Growth vs Reduction Bars)
          if (root.showChangeColumns) {
            var maxRate = 0.001
            var colRates = []
            for (var ri = 0; ri < root.trajectory.length; ri++) {
              var rCur = root.trajectory[ri]
              var rPrev = ri > 0 ? root.trajectory[ri - 1] : rCur
              var rNext = ri < root.trajectory.length - 1 ? root.trajectory[ri + 1] : rCur
              var rdt = 0, rdp = 0
              if (ri > 0) {
                rdt = rCur.year - rPrev.year
                rdp = rCur.pop - rPrev.pop
              } else {
                rdt = rNext.year - rCur.year
                rdp = rNext.pop - rCur.pop
              }
              var rNet = rdt !== 0 ? (rdp / rdt) : 0.0
              colRates.push({ year: rCur.year, rate: rNet })
              if (Math.abs(rNet) > maxRate) maxRate = Math.abs(rNet)
            }

            var colMaxHeight = 24.0
            var baseY = marginT + plotH
            for (var ci = 0; ci < colRates.length; ci++) {
              var cItem = colRates[ci]
              var cx = root.getX(cItem.year, plotW, marginL)
              var barH = Math.max(1.5, (Math.abs(cItem.rate) / maxRate) * colMaxHeight)
              var isGrowing = cItem.rate > 0.005
              var isDeclining = cItem.rate < -0.005
              var isPeak = !isGrowing && !isDeclining

              var isActive = (cItem.year === root.activeYear)
              var colW = Math.max(2.5, Math.min(5.0, (plotW / colRates.length) * 0.70))

              ctx.fillStyle = isPeak
                ? (isActive ? "#fbbf24" : "rgba(251, 191, 36, 0.45)")
                : isGrowing
                  ? (isActive ? "#4ade80" : "rgba(74, 222, 128, 0.40)")
                  : (isActive ? "#f87171" : "rgba(248, 113, 113, 0.40)")

              ctx.fillRect(cx - colW / 2, baseY - barH, colW, barH)

              if (isActive) {
                ctx.strokeStyle = "#ffffff"
                ctx.lineWidth = 1
                ctx.strokeRect(cx - colW / 2, baseY - barH, colW, barH)
              }
            }
          }

          // 4. Draw Historical Curve
          if (histPts.length > 1) {
            ctx.beginPath()
            ctx.lineWidth = 2.5
            ctx.strokeStyle = "#38bdf8" // Sky Blue
            ctx.moveTo(histPts[0].x, histPts[0].y)
            for (var hi = 1; hi < histPts.length; hi++) ctx.lineTo(histPts[hi].x, histPts[hi].y)
            ctx.stroke()
          }

          // 5. Draw Future Projection Curve
          if (futPts.length > 1) {
            ctx.beginPath()
            ctx.lineWidth = 2.5
            ctx.strokeStyle = root.isSubReplacement ? "#f87171" : "#4ade80" // Coral/Red vs Emerald
            ctx.moveTo(futPts[0].x, futPts[0].y)
            for (var fi = 1; fi < futPts.length; fi++) ctx.lineTo(futPts[fi].x, futPts[fi].y)
            ctx.stroke()
          }

          // 6. Draw Milestone Highlight Dots
          // Peak Point Dot
          if (root.countryData.peakYear) {
            var peakX = root.getX(root.countryData.peakYear, plotW, marginL)
            var peakY = root.getY(root.countryData.peakPopulation, plotH, marginT)
            ctx.beginPath()
            ctx.arc(peakX, peakY, 4, 0, 2 * Math.PI)
            ctx.fillStyle = "#fbbf24" // Amber
            ctx.fill()
            ctx.lineWidth = 1.5
            ctx.strokeStyle = "#000"
            ctx.stroke()

            ctx.font = "8px monospace"
            ctx.fillStyle = "#fbbf24"
            ctx.textAlign = "center"
            ctx.fillText("PEAK", peakX, Math.max(marginT + 10, peakY - 8))
          }

          // Halving Point Dot
          if (root.isSubReplacement && root.countryData.halvingYear) {
            var halfPop = root.countryData.peakPopulation * 0.5
            var halfX = root.getX(root.countryData.halvingYear, plotW, marginL)
            var halfY = root.getY(halfPop, plotH, marginT)
            ctx.beginPath()
            ctx.arc(halfX, halfY, 4, 0, 2 * Math.PI)
            ctx.fillStyle = "#f43f5e" // Rose/Red
            ctx.fill()
            ctx.lineWidth = 1.5
            ctx.strokeStyle = "#000"
            ctx.stroke()

            ctx.font = "8px monospace"
            ctx.fillStyle = "#f43f5e"
            ctx.textAlign = "center"
            ctx.fillText("T½ 50%", halfX, Math.max(marginT + 10, halfY - 8))
          }

          // Zero / Extinction Point Dot
          if (root.isSubReplacement && root.countryData.extinctionYear) {
            var extX = root.getX(root.countryData.extinctionYear, plotW, marginL)
            var extY = root.getY(0, plotH, marginT)
            ctx.beginPath()
            ctx.arc(extX, extY, 4.5, 0, 2 * Math.PI)
            ctx.fillStyle = "#dc2626" // Deep Red
            ctx.fill()
            ctx.lineWidth = 1.5
            ctx.strokeStyle = "#fff"
            ctx.stroke()

            ctx.font = "8px monospace"
            ctx.fillStyle = "#dc2626"
            ctx.textAlign = "center"
            ctx.fillText("~0", extX, extY - 8)
          }

          // 2026 Current Year Marker Dot
          var y2026 = root.getY(root.countryData.population2026, plotH, marginT)
          ctx.beginPath()
          ctx.arc(x2026, y2026, 5, 0, 2 * Math.PI)
          ctx.fillStyle = "#ffffff"
          ctx.fill()
          ctx.lineWidth = 2
          ctx.strokeStyle = "#38bdf8"
          ctx.stroke()

          // 7. Interactive Hover Cursor
          var targetYear = root.isHovered ? root.hoveredYear : parseInt(root.selectedYear, 10)
          if (targetYear >= root.startYear && targetYear <= root.endYear) {
            var curX = root.getX(targetYear, plotW, marginL)
            var curPt = root.trajectory.find(function(p) { return p.year === targetYear })
            var curY = curPt ? root.getY(curPt.pop, plotH, marginT) : y2026

            // Vertical cursor line
            ctx.beginPath()
            ctx.setLineDash([2, 2])
            ctx.strokeStyle = "rgba(255, 255, 255, 0.6)"
            ctx.moveTo(curX, marginT)
            ctx.lineTo(curX, marginT + plotH)
            ctx.stroke()
            ctx.setLineDash([])

            // Pulsing cursor circle
            ctx.beginPath()
            ctx.arc(curX, curY, 6, 0, 2 * Math.PI)
            ctx.fillStyle = targetYear <= 2026 ? "#38bdf8" : (root.isSubReplacement ? "#f87171" : "#4ade80")
            ctx.fill()
            ctx.lineWidth = 2
            ctx.strokeStyle = "#fff"
            ctx.stroke()
          }
        }
      }

      MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true

        function updateHover(mX) {
          var marginL = 36
          var marginR = 24
          var plotW = width - marginL - marginR
          var pt = root.findPointForMouse(mX, plotW, marginL)
          if (pt) {
            root.isHovered = true
            root.hoveredYear = pt.year
            root.hoveredPop = pt.pop
            root.yearSelected(String(pt.year))
            canvas.requestPaint()
          }
        }

        onPositionChanged: function(mouse) {
          updateHover(mouse.x)
        }

        onPressed: function(mouse) {
          updateHover(mouse.x)
        }

        onExited: {
          root.isHovered = false
          canvas.requestPaint()
        }
      }
    }
  }
}
