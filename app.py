from flask import Flask, render_template, request, flash, url_for, session, redirect, jsonify, Response, make_response
import json
import neo
import netx

# Configuration 
DEBUG = True
SECRET_KEY = 'A0Zr98j/3yX R~XHH!jmN]LWX/,?RT'
USER_NAME = 'syngnz'
PASSWORD = 'inform'

APP = Flask(__name__)
APP.config.from_object(__name__)

# Cache the results on server
NODE_CACHE = []
REL_CACHE = []


@APP.route('/about')
def about():
    return render_template('about.html')


@APP.route('/discuss')
def discuss():
    return render_template('discuss.html')


@APP.route('/build')
def build():
    neo.db_add_neurons(clear=True)
    neo.db_add_synapses(clear=False)
    return redirect(url_for('index'))


@APP.route('/')
def index():
    global NODE_CACHE, REL_CACHE
    NODE_CACHE = neo.neurons()
    REL_CACHE = neo.synapses_d3(NODE_CACHE, min_weight=0)
    jsn = json.dumps({'neurons':NODE_CACHE, 'synapses':REL_CACHE})
    return render_template('graph.html', data=jsn)


@APP.route('/_subgraph')
def subgraph():
    global NODE_CACHE, REL_CACHE
    gr1 = request.args.get('group1', "no group1", type=str)
    gr1 = [s.strip() for s in gr1.split(",") if not s.isspace()]
    gr2 = request.args.get('group2', "no group2", type=str)
    gr2 = [s.strip() for s in gr2.split(",") if not s.isspace()]
    rec = request.args.get('receptors', "", type=str)
    rec = [s.strip() for s in rec.split(",") if s and not s.isspace()] # empty list (falsy) when none
    mus = request.args.get('muscles', "", type=str)
    mus = [s.strip() for s in mus.split(",") if s and not s.isspace() ] # empty list (falsy) when none
    min_ws = request.args.get('minWeightS', 1, type=int)
    min_wj = request.args.get('minWeightJ', 1, type=int)
    max_l = request.args.get('maxLength', 2, type=int)
    path_dir = request.args.get('dir', 'uni', type=str)
    res = neo.subgraph(gr1, gr2, max_l, min_ws, min_wj, path_dir, rec, mus)
    NODE_CACHE = res['neurons']
    REL_CACHE = res['synapses']
    return jsonify(result=res)


@APP.route('/_expand')
def expand():
    global NODE_CACHE, REL_CACHE
    names = request.args.getlist('names[]')
    mus = request.args.get('muscles', "", type=str)
    mus = [s.strip() for s in mus.split(",") if s and not s.isspace() ] # empty list (falsy) when none
    res = neo.all_cons_for_set(names, mus)
    NODE_CACHE = res['neurons']
    REL_CACHE = res['synapses']    
    return jsonify(result=res)


@APP.route('/_reset')
def reset():
    global NODE_CACHE, REL_CACHE
    NODE_CACHE = neo.neurons()
    REL_CACHE = neo.synapses_d3(NODE_CACHE, min_weight=0)
    res = {'neurons':NODE_CACHE, 'synapses':REL_CACHE}
    return jsonify(result=res)


@APP.route('/export', methods=["GET"])
def export():
    print request.args
    exp_format = request.args.get('format', "json", type=str)
    nxg = netx.to_netx(NODE_CACHE, REL_CACHE)
    
    if "json" in exp_format:
        jsg = netx.to_json(nxg, exp_format)
        resp = Response(jsg, mimetype="application/json")
    elif "graphml" in exp_format:
        text = netx.to_graphml(nxg)
        resp = Response(text, mimetype="text/plain")
    elif "gml" in exp_format:
        text = netx.to_gml(nxg)
        resp = Response(text, mimetype="text/plain")
    elif "adj" in exp_format:
        text = netx.to_adj(nxg)
        resp = Response(text, mimetype="text/plain")
    
    return resp


@APP.route('/downloadSvg', methods=["GET"])
def downloadSvg():
    print request.args
    svg_source = request.args.get('svg-source', "", type=str)
    #resp = Response(svg_source, mimetype="svg")
    resp = make_response(svg_source)
    resp.headers["Content-Disposition"] = "attachment; filename=graph.svg"
    return resp


@APP.route('/sigma')
def sigma():
    n_sig = neo.neurons_sigma()
    s_sig = neo.synapses_sigma(n_sig, 2)
    jsn = json.dumps({'nodes':n_sig, 'edges':s_sig})
    return render_template('sigma.html', data=jsn)


@APP.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        if request.form['username'] != APP.config['USER_NAME']:
            error = 'Invalid username'
        elif request.form['password'] != APP.config['PASSWORD']:
            error = 'Invalid password'
        else:
            session['logged_in'] = True
            flash('You were logged in')
            return redirect(url_for('show_runs'))

    flash(error)
    return redirect(url_for('show_runs'))


@APP.route('/logout')
def logout():
    session.pop('logged_in', None)
    flash('You were logged out')
    return redirect(url_for('show_runs'))


# Autostart
# ------------------------------------------------------------------------------
if __name__ == '__main__':
    APP.run(debug=True)
