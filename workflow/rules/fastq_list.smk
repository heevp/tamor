import os.path
import csv
import glob

#include: "metadata.smk"

configfile: "config/config.yaml"

# One or more libraries correspond to a single sample defined by the wildcard match values for a sequencing run. 
# Generate a file listing all those FASTQ files so they can be processed together, e.g. for reference mapping.
def make_sample_fastq_list_csv(wildcards, is_rna, is_tumor, sample_libraries):
        # We could generate a combined FASTQ file, but this takes up a lot of extra space and tmp dir might fill for somatic genomes for example
        # Instead we will generate a fastq-list file that contains all the libraries for the sample (you may have more than one as in XP loading you can't name same sample ID across lanes for same sample name) 
        # Since a sample could have been spread across multiple runs, we need to have a run-agnostic name for the FASTQ list file. The natural spot is the "output" dir, even if
        # this is not an output in any practical sense of the pipeline.
        if is_rna:
                sample_fastq_list_csv = config["output_dir"]+'/'+wildcards.project+'/'+wildcards.subject+'/rna/'+wildcards.sample+'_fastq_list.csv'
                target_sample = wildcards.sample
        elif is_tumor and hasattr(wildcards, "tumor"):
                sample_fastq_list_csv = config["output_dir"]+'/'+wildcards.project+'/'+wildcards.subject+'/'+wildcards.tumor+'_fastq_list.csv'
                target_sample = wildcards.tumor
        elif hasattr(wildcards, "normal"):
                sample_fastq_list_csv = config["output_dir"]+'/'+wildcards.project+'/'+wildcards.subject+'/'+wildcards.normal+'_fastq_list.csv'
                target_sample = wildcards.normal
        elif hasattr(wildcards, "sample"):
                sample_fastq_list_csv = config["output_dir"]+'/'+wildcards.project+'/'+wildcards.subject+'/'+wildcards.sample+'_fastq_list.csv'
                target_sample = wildcards.sample
        else:
                raise Error("Wildcards have no useable attribute (tumor, normal, or sample) in call to make_sample_fastq_list_csv")
        header_printed = False
        with open(sample_fastq_list_csv, 'w') as f:
                # Gather file specs from all run that have been converted.
                for fastq_list_csv in glob.iglob(config["analysis_dir"]+'/primary/'+config["sequencer"]+'/*/Reports/fastq_list.csv'):
                        #print('Reading samples from '+fastq_list_csv+' while looking for sample ' + target_sample)
                        with open(fastq_list_csv, 'r') as data_in:
                                csv_file = csv.reader(data_in)
                                if not header_printed:
                                        # Print the header line
                                        f.write(",".join(next(csv_file)))
                                        f.write('\n')
                                        header_printed = True
                                for line in csv_file:
                                        if line[1] in sample_libraries:
                                                # We might have different sample names for the same sample like Li###-lane1
                                                # and this will cause problems downstream, e.g. when somatic mutation calling
                                                # and dragen enforces a single sample name in the source BAM. So replace any existing name.
                                                line[2] = target_sample
                                                # We may also have rewritten the .fastq.gz as a .ora file to save room. In that case we need to write the .ora name to the new list
                                                if not os.path.isfile(line[4]):
                                                        orafile = line[4].replace(".fastq.gz",".fastq.ora")
                                                        if not os.path.isfile(orafile):
                                                                print('Cannot find target FASTQ file specified in ' + fastq_list_csv  + ', may fail subsequently without: ' + line[4])
                                                        line[4] = orafile
                                                if not os.path.isfile(line[5]):
                                                        orafile = line[5].replace(".fastq.gz",".fastq.ora")
                                                        if not os.path.isfile(orafile):
                                                                print('Cannot find target FASTQ file specified in ' + fastq_list_csv  + ', may fail subsequently without: ' + line[5])
                                                        line[5] = orafile
                                                f.write(",".join(line))
                                                f.write('\n')
        return sample_fastq_list_csv

def get_sample_fastq_list_csvs(wildcards, is_rna, is_tumor):
        library_info = identify_libraries(is_rna, is_tumor, wildcards)
        all_csvs_with_sample = [];
        # Gather file specs from all run that have been converted.
        for fastq_list_csv in glob.iglob(config["analysis_dir"]+'/primary/'+config["sequencer"]+'/*/Reports/fastq_list.csv'):
                with open(fastq_list_csv, 'r') as data_in:
                        csv_file = csv.reader(data_in)
                        for line in csv_file:
                                if line[1] in library_info[1]:
                                        all_csvs_with_sample.append(fastq_list_csv)
                                        break;
        return all_csvs_with_sample

def get_normal_dna_sample_fastq_list_csvs(wildcards):
        return get_sample_fastq_list_csvs(wildcards, False, False) # booleans: is not RNA, is not Tumor

def get_tumor_dna_sample_fastq_list_csvs(wildcards):
        return get_sample_fastq_list_csvs(wildcards, False, True) # booleans: is not RNA, is Tumor

def get_rna_sample_fastq_list_csvs(wildcards):
        return get_sample_fastq_list_csvs(wildcards, True, True) # booleans: is RNA, is Tumor
