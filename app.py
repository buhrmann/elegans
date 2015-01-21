from flask import Flask, render_template, request, flash, url_for, session, redirect, jsonify, Response
import json
import neo
import netx

# Configuration 
DEBUG = True
SECRET_KEY = 'A0Zr98j/3yX R~XHH!jmN]LWX/,?RT'
USER_NAME = 'syngnz'
PASSWORD = 'inform'

app = Flask(__name__)
app.config.from_object(__name__)

# Cache the results on server
n_cache = []
s_cache = []

@app.route('/build')
def build():
    neo.dbAddNeurons(True)
    neo.dbAddSynapses(False)
    return redirect(url_for('index'))


@app.route('/')
@app.route('/graph')
def index():
    global n_cache, s_cache
    n_cache = neo.neurons()
    s_cache = neo.synapsesD3(n_cache, 0)
    d = {'neurons':n_cache, 'synapses':s_cache}
    j = json.dumps(d)
    return render_template('graph.html', data=j)


@app.route('/_subgraph')
def subgraph():
    global n_cache, s_cache
    g1 = request.args.get('group1', "no group1", type=str)
    g1 = [s.strip() for s in g1.split(",")]
    g2 = request.args.get('group2', "no group2", type=str)
    g2 = [s.strip() for s in g2.split(",")]
    ws = request.args.get('minWeightS', 1, type=int)
    wj = request.args.get('minWeightJ', 1, type=int)
    l = request.args.get('maxLength', 2, type=int)
    dir = request.args.get('dir', '->', type=str)
    res = neo.subgraph(g1, g2, l, ws, wj, dir)    
    n_cache = res['neurons']
    s_cache = res['synapses']
    return jsonify(result=res)


@app.route('/_expand')
def expand():
    global n_cache, s_cache
    names = request.args.getlist('names[]')
    res = neo.allConsForSet(names)    
    n_cache = res['neurons']
    s_cache = res['synapses']    
    return jsonify(result=res)


@app.route('/_reset')
def reset():
    global n_cache, s_cache
    n_cache = neo.neurons()
    s_cache = neo.synapsesD3(n_cache, 0)
    res = {'neurons':n_cache, 'synapses':s_cache}
    return jsonify(result=res)


@app.route('/export')
def export():
    nxg = netx.toNx(n_cache, s_cache)
    jsg = netx.toJson(nxg)
    resp = Response(jsg, mimetype="application/json")
    return resp


@app.route('/sigma')
def sigma():
    ns = neo.neuronsSigma()
    ss = neo.synapsesSigma(ns, 2)
    d = {'nodes':ns, 'edges':ss}
    j = json.dumps(d)
    return render_template('sigma.html', data=j)


@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        if request.form['username'] != app.config['USER_NAME']:
            error = 'Invalid username'
        elif request.form['password'] != app.config['PASSWORD']:
            error = 'Invalid password'
        else:
            session['logged_in'] = True
            flash('You were logged in')
            return redirect(url_for('show_runs'))

    flash(error)
    return redirect(url_for('show_runs'))


@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    flash('You were logged out')
    return redirect(url_for('show_runs'))


# Autostart
# ------------------------------------------------------------------------------
if __name__ == '__main__':
    app.run(debug=True)