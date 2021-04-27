#!/usr/bin/env python
# -*- coding: utf-8 -*-

import time
import os
import argparse
import yaml

from termcolor import colored

import ROOT

ROOT.gROOT.SetBatch()
ROOT.gStyle.SetOptStat(0)

def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Compare tau quantities between two miniAOD samples.")
    parser.add_argument(
        "--input-dev",
        required=True,
        type=str,
        help="Input file from development.")
    parser.add_argument(
        "--input-ref",
        required=True,
        type=str,
        help="Input file from reference.")
    parser.add_argument(
        "-m",
        "--max-taus",
        type=int,
        default=-1,
        help="Maximum number of processed taus.")
    parser.add_argument(
        "-n",
	"--n-bins",
        type=int,
        default=100,
        help="Number of bins per histogram. Default: %(default)s")
    parser.add_argument(
        "-q",
        "--quantities",
        nargs='+',
        type=str,
        default=[],
        help="List of quantities to compare. Prepend 'id:' to ID quantities.")
    parser.add_argument(
        "-o",
        "--outdir",
        type=str,
        help="Input file from reference.")
    parser.add_argument(
        "--tau-type",
        type=str,
        default="Tau",
        help="Type of taus in compared samples. Default: %(default)s")

    return parser.parse_args()

def compare(quantity, input_dev, input_ref, ranges, outdir, max_taus, nbins, name, tau_type):
    f_dev = ROOT.TFile(input_dev, "READ")
    f_ref = ROOT.TFile(input_ref, "READ")
    e_dev = f_dev.Get("Events")
    e_ref = f_ref.Get("Events")
    c1=ROOT.TCanvas()
    r = [0.0, 1.01]
    if quantity.split(":")[0] in ranges.keys():
        r = ranges[quantity.split(":")[0]]
    h_ref = ROOT.TH1F(quantity, quantity, nbins, r[0], r[1])
    h_dev = ROOT.TH1F(quantity+"_dev", quantity+"_dev", nbins, r[0], r[1])
    max=max_taus
    for event in e_ref:
        if max==0:
            break
        taus = list(getattr(event, tau_type+"_"+quantity.split(":")[0]))
        for tau in taus:
            if max==0:
                break
            if ":" in quantity:
                tau = min(1, tau & 1 << int(quantity.split(":")[1]) - 1) #name provides nth bit (without 0) according to bitmask documented in nanoAOD tree
            h_ref.Fill(tau)
            max-=1
    max=max_taus
    for event in e_dev:
        if max==0:
            break
        taus = list(getattr(event, tau_type+"_"+quantity.split(":")[0]))
        for tau in taus:
            if max==0:
                break
            if ":" in quantity:
                tau = min(1, tau & 1 << int(quantity.split(":")[1]) - 1) #name provides nth bit (without 0) according to bitmask documented in nanoAOD tree
            h_dev.Fill(tau)
            max-=1

    equal = True
    for i in range(1, nbins+1):
        if h_ref.GetBinContent(i)!=h_dev.GetBinContent(i):
            equal = False
            break

    h_ref.SetLineWidth(2)
    h_dev.SetLineWidth(2)
    h_dev.SetLineColor(8 if equal else 2)
    h_dev.SetLineStyle(7)
    h_ref.Draw("hist")
    h_dev.Draw("histsame")
    c1.SaveAs(os.path.join(outdir, "%s_%s.png"%(name, quantity)))

    f_dev.Close()
    f_ref.Close()

    return equal

def main(args):
    ranges = yaml.safe_load(open(os.path.join(os.getenv("TS_DIR"), "test/ranges.yaml")))
    outdir = os.path.join(os.getenv("TS_DIR"), "projects", os.getenv("TS_PROJECT_NAME"), "test") if args.outdir==None else args.outdir
    name = os.path.basename(args.input_ref.replace("_ref.root",""))

    results={}
    failing_q=[]
    for q in args.quantities:
        # Access to root histograms sometimes fails within the event loop. Usually works upon repetition.
        for i in range(10):
            try:
                results[q] = compare(q, args.input_dev, args.input_ref, ranges, outdir, args.max_taus, args.n_bins, name, args.tau_type)
                if q in failing_q:
                    failing_q.remove(q)
                    print "Comparison of %s finally worked!"%q
                break
            except TypeError:
                failing_q.append(q)
                print "Rerunning comparison of %s due to ROOT error!"%q
            except AttributeError:
                failing_q.append(q)
                print "Rerunning comparison of %s due to ROOT error!"%q
    n_diffs=0
    print "___Summary___:"
    for	q in args.quantities:
        if q in failing_q:
            print q, colored("TECHNICAL ERROR", "red")
        else:
            if not results[q]:
                print q, colored("DIFFERS", "red")
                n_diffs += 1
            else:
                print q, colored("ok", "green")
    print ""
    if n_diffs==0:
        print colored("No differences found!", "green")
    else:
        print colored("Found differences in %i quantities!"%n_diffs, "red")

if __name__ == "__main__":
    args = parse_arguments()
    main(args)
