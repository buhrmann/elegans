from flask import Flask, render_template, request, flash, url_for, session, redirect, jsonify
import json
import neo

# Configuration 
DEBUG = True
SECRET_KEY = 'A0Zr98j/3yX R~XHH!jmN]LWX/,?RT'
USER_NAME = 'syngnz'
PASSWORD = 'inform'

app = Flask(__name__)
app.config.from_object(__name__)

@app.route('/info')
def info():
    o = neo.g.order
    s = neo.g.size
    print o, s
    return 'Graph has ' + str(o) + ' neurons and ' + str(s) +  ' synapses.' 

@app.route('/build')
def build():
    neo.addNeurons(True)
    neo.addSynapses(False)
    neo.addNodeDegrees()
    return redirect(url_for('index'))


@app.route('/')
@app.route('/graph')
def index():
    ns = neo.neurons()
    ss = neo.synapsesD3(ns, 0)
    d = {'neurons':ns, 'synapses':ss}
    j = json.dumps(d)
    return render_template('graph.html', data=j)


@app.route('/_subgraph')
def subgraph():
    g1 = request.args.get('group1', "no group1", type=str)
    g1 = [s.strip() for s in g1.split(",")]
    g2 = request.args.get('group2', "no group2", type=str)
    g2 = [s.strip() for s in g2.split(",")]
    w = request.args.get('minWeight', 1, type=int)
    l = request.args.get('maxLength', 2, type=int)
    dir = request.args.get('dir', '->', type=str)
    res = neo.subgraph(g1, g2, l, w, dir)
    return jsonify(result=res)


@app.route('/_reset')
def reset():
    ns = neo.neurons()
    ss = neo.synapsesD3(ns, 0)
    res = {'neurons':ns, 'synapses':ss}
    return jsonify(result=res)


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