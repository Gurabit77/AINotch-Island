// Agents Status Extension for Agent Halo
// Shows a compact summary of active agents in the notch

var lastStatus = "idle";
var blinkState = false;

function activate() {
    console.log("agents-status extension activated");
    setInterval(function() {
        blinkState = !blinkState;
    }, 1000);
}

function deactivate() {
    console.log("agents-status extension deactivated");
}

function render() {
    var agents = AgentHalo.agents.getAgents();
    var status = AgentHalo.agents.getStatus();
    var count = AgentHalo.agents.getActiveCount();

    if (count === 0) {
        return renderIdle();
    }
    return renderActive(agents, status, count);
}

function renderIdle() {
    return UI.hstack([
        UI.image("circle.hexagongrid", { style: { fontSize: 10, foregroundColor: "gray", opacity: 0.5 } }),
        UI.text("No agents", { fontSize: 10, foregroundColor: "gray", opacity: 0.6 })
    ], { spacing: 4 });
}

function renderActive(agents, status, count) {
    var statusColor = "green";
    var statusIcon = "circle.fill";
    if (status === "waiting") { statusColor = "orange"; statusIcon = "exclamationmark.circle.fill"; }
    if (status === "error") { statusColor = "red"; statusIcon = "xmark.circle.fill"; }

    var items = [
        UI.image(statusIcon, { style: { fontSize: 8, foregroundColor: statusColor } }),
        UI.text(count + " agent" + (count > 1 ? "s" : ""), { fontSize: 11, fontWeight: "medium", foregroundColor: "white" })
    ];

    if (status === "waiting" && blinkState) {
        items.push(UI.text("!", { fontSize: 10, fontWeight: "bold", foregroundColor: "orange" }));
    }

    return UI.hstack(items, { spacing: 5 });
}
