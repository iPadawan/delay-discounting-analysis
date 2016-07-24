// ********************************************** WORK IN PROGRESS

data {
  int <lower=1> totalTrials;
  int <lower=1> nParticipants;

  vector[totalTrials] A;
  vector[totalTrials] B;
  vector<lower=0>[totalTrials] DA;
  vector<lower=0>[totalTrials] DB;
  int <lower=0,upper=1> R[totalTrials];
  int <lower=0,upper=nParticipants> ID[totalTrials];
}

parameters {
  real groupALPHAmu;
  real <lower=0> groupALPHAsigma;

  real <lower=0,upper=1>groupW;
  real groupKminus2;

  // participant level
  vector[nParticipants] m;
  vector[nParticipants] c;
  vector<lower=0>[nParticipants] alpha;
  vector<lower=0,upper=0.5>[nParticipants] epsilon;
}

transformed parameters {
  // group LEVEL
  real groupK;

  vector[totalTrials] lkA;
  vector[totalTrials] lkB;

  vector[totalTrials] VA;
  vector[totalTrials] VB;

  vector[totalTrials] P;

  groupK <- groupKminus2+2;

  for (t in 1:totalTrials){
    // Magnitude Effect
    lkA[t] <- m[ID[t]]*log(fabs(A[t]))+c[ID[t]];
    lkB[t] <- m[ID[t]]*log(fabs(B[t]))+c[ID[t]];

    // calculate present subjective value for each reward
    VA[t] <- A[t] / (1+(exp(lkA[t])*DA[t]));
    VB[t] <- B[t] / (1+(exp(lkB[t])*DB[t]));

    // Psychometric function
    P[t] <- epsilon[ID[t]] + (1-2*epsilon[ID[t]]) * Phi( (VB[t]-VA[t]) / alpha[ID[t]] );
  }
}

model {
  // GROUP LEVEL PRIORS ======================================================
  groupALPHAmu    ~ uniform(0, 100);
  groupALPHAsigma ~ uniform(0, 100);
  groupW          ~ beta(1.1, 10.9);  // mode for lapse rate
  groupKminus2    ~ gamma(0.01, 0.01); // concentration parameter

  // PARTICIPANT LEVEL =======================================================
  m        ~ normal(-0.243, 0.5);
  c        ~ normal(0, 10);
  epsilon  ~ beta(groupW*(groupK-2)+1 , (1-groupW)*(groupK-2)+1 );
  alpha    ~ normal(groupALPHAmu, groupALPHAsigma);

  R ~ bernoulli(P);
}

generated quantities { // see page 76 of manual
  // NO VECTORIZATION IN THIS BLOCK

  int <lower=0,upper=1> Rpostpred[totalTrials];

  for (t in 1:totalTrials){
    Rpostpred[t] <- bernoulli_rng(P[t]);
  }

}
