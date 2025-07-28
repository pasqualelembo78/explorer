from flask import Flask, render_template, request, redirect, url_for
import requests
import time

app = Flask(__name__)

JSON_RPC_URL = "http://127.0.0.1:17081/json_rpc"
GETINFO_URL = "http://127.0.0.1:17081/getinfo"
WALLET_RPC_URL = "http://127.0.0.1:17082/json_rpc"
HEADERS = {"Content-Type": "application/json"}

def wallet_rpc_call(method, params=None):
    payload = {
        "jsonrpc": "2.0",
        "id": "0",
        "method": method,
        "params": params or {}
    }
    r = requests.post(WALLET_RPC_URL, json=payload, headers=HEADERS)
    return r.json()

@app.route("/")
def homepage():
    try:
        info = requests.get(GETINFO_URL).json()
        height = info.get("height", 0)
        hashrate = info.get("hashrate", 0)
        difficulty = info.get("difficulty", 0)
        last_block = info.get("last_known_block_index", 0)
    except Exception as e:
        return f"<h2>Errore nel recuperare info: {e}</h2>"

    blocks = []
    num_blocks = 20
    start = max(height - num_blocks + 1, 0)

    for h in range(start, height + 1):
        try:
            res = requests.post(
                JSON_RPC_URL,
                json={
                    "jsonrpc": "2.0",
                    "id": "0",
                    "method": "getblockheaderbyheight",
                    "params": {"height": h}
                },
                headers={"Content-Type": "application/json"}
            )
            block_header = res.json().get("result", {}).get("block_header", {})

            timestamp = block_header.get("timestamp", 0)
            reward = block_header.get("reward", 0) / 1e5
            tx_count = block_header.get("num_txes", 0)

            blocks.append({
                "height": block_header.get("height", h),
                "hash": block_header.get("hash", "n/a"),
                "timestamp": time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(timestamp)) if timestamp else "n/a",
                "tx_count": tx_count,
                "reward": reward
            })

        except Exception as ex:
            blocks.append({
                "height": h,
                "hash": "Errore",
                "timestamp": "Errore",
                "tx_count": 0,
                "reward": 0
            })

    return render_template("index.html",
                           height=height,
                           hashrate=hashrate,
                           difficulty=difficulty,
                           last_block=last_block,
                           blocks=reversed(blocks))


@app.route("/tx/<tx_hash>")
def transaction_detail(tx_hash):
    resp = wallet_rpc_call("getTransaction", {"transactionHash": tx_hash})
    if "result" in resp:
        tx = resp["result"]

        timestamp = tx.get("timestamp", 0)
        readable_time = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(timestamp)) if timestamp else "N/A"

        return render_template("transaction.html", tx=tx, timestamp=readable_time)
    else:
        return f"<h2>Transazione non trovata: {tx_hash}</h2>"

@app.route("/search", methods=["GET", "POST"])
def search():
    if request.method == "POST":
        query = request.form.get("query", "").strip()
        if len(query) == 64:  # controllo semplice hash
            return redirect(url_for("transaction_detail", tx_hash=query))
        else:
            return "<h3>Query non valida o non supportata</h3>"
    return render_template("search.html")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
