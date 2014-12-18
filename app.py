from flask import Flask, render_template, request, flash, url_for, session, redirect
import json
import neo

# Configuration 
DEBUG = True
SECRET_KEY = 'A0Zr98j/3yX R~XHH!jmN]LWX/,?RT'
USER_NAME = 'syngnz'
PASSWORD = 'inform'

app = Flask(__name__)
app.config.from_object(__name__)

@app.route('/')
def index():
    o = neo.g.order
    s = neo.g.size
    print o, s
    return 'Graph has ' + str(o) + ' neurons and ' + str(s) +  ' synapses.' 


@app.route('/build')
def build():
    neo.addNeurons(True)
    neo.addSynapses(False)
    return redirect(url_for('graph'))


@app.route('/graph')
def graph():
    ns = neo.neurons()
    ss = neo.synapsesId(ns, 5)
    d = {'neurons':ns, 'synapses':ss}
    j = json.dumps(d)
    return render_template('graph.html', data=j)


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