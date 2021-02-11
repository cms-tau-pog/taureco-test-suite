#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import argparse
import yaml

from termcolor import colored

from DataFormats.FWLite import Handle, Events
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
        "--tau-type",
        type=str,
        default="slimmedTaus",
        help="Type of taus in compared samples. Default: %(default)s")
    parser.add_argument(
        "-o",
        "--outdir",
        type=str,
        help="Input file from reference.")

    return parser.parse_args()

def compare(quantity, input_dev, input_ref, tau_type, ranges, outdir, max_taus, nbins, name):
    e_dev = Events(input_dev)
    e_ref = Events(input_ref)
    tau_handle = Handle("std::vector<pat::Tau>")
    c1=ROOT.TCanvas()
    r = [0, 1]
    if quantity in ranges.keys():
        r = ranges[quantity]
    isID = False
    idxID = -1
    if quantity.startswith("id:"):
        isID = True
        quantity = quantity.replace("id:", "")
    h_ref = ROOT.TH1F(quantity, quantity, nbins, r[0], r[1])
    h_dev = ROOT.TH1F(quantity+"_dev", quantity+"_dev", nbins, r[0], r[1])
    max=max_taus
    for event in e_ref:
        if max==0:
            break
        event.getByLabel(tau_type, tau_handle)
        taus = tau_handle.product()
        for tau in taus:
            if max==0:
                break
            if isID:
                if idxID==-1:
                    for i, ID in enumerate(tau.tauIDs()):
                        if ID.first==quantity:
                            idxID = i
                            break
                h_ref.Fill(tau.tauIDs()[idxID].second)
            else:
                h_ref.Fill(getattr(tau, quantity))
            max-=1
    max=max_taus
    for event in e_dev:
        if max==0:
            break
        event.getByLabel(tau_type, tau_handle)
        taus = tau_handle.product()
        for tau in taus:
            if max==0:
                break
            if isID:
                h_dev.Fill(tau.tauIDs()[idxID].second)
            else:
                h_dev.Fill(getattr(tau, quantity))
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

    return equal

def main(args):
    ranges = yaml.load(open(os.path.join(os.getenv("TS_DIR"), "test/ranges.yaml")))
    outdir = os.path.join(os.getenv("TS_DIR"), "projects", os.getenv("TS_PROJECT_NAME"), "test") if args.outdir==None else args.outdir
    name = os.path.basename(args.input_ref.replace("_ref.root",""))

    results={}
    for q in args.quantities:
        results[q] = compare(q, args.input_dev, args.input_ref, args.tau_type, ranges, outdir, args.max_taus, args.n_bins, name)
    n_diffs=0
    print "___Summary___:"
    for	q in args.quantities:
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
