region-manager-lke-cluster = [
    {
        label : "region-manager-lke-cluster"
        k8s_version : "1.25"
        region : "us-west"
        pools = [
            {
                type : "g6-standard-2"
                count : 1
            }
        ]
    }
]

/*************************
label = "us-lke-cluster"
k8s_version = "1.25"
region = "us-west"
pools = [
  {
    type : "g6-standard-2"
    count : 1
  }
]

/****************************************
label = "eu-lke-cluster"
k8s_version = "1.25"
region = "eu-west"
pools = [
  {
    type : "g6-standard-2"
    count : 1
  }
]

/****************************************
label = "ap-lke-cluster"
k8s_version = "1.25"
region = "ap-south"
pools = [
  {
    type : "g6-standard-2"
    count : 1
  }
]

*/