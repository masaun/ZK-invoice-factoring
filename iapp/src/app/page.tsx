"use client";

import { useEffect, useState } from "react";
import { useAppKit } from "@reown/appkit/react";
import { useAccount, useDisconnect, useChainId, useSwitchChain } from "wagmi";
import {
  IExecDataProtector,
  ProtectedData,
  GrantedAccess,
} from "@iexec/dataprotector";
import WelcomeBlock from "@/components/WelcomeBlock";
import wagmiNetworks, { explorerSlugs } from "@/config/wagmiNetworks";

interface TaskStatus {
  taskId: string;
  dealId?: string;
  status: 'PENDING' | 'ACTIVE' | 'COMPLETED' | 'FAILED' | 'TIMEOUT';
  isDone: boolean;
  title: string;
}

interface Invoice {
  invoice_id: number;
  invoice_supplier_id: number;
  invoice_buyer_id: number;
  invoice_amount: number;
  invoice_due_date: number;
  invoice_acceptance_timestamp: number;
}

export default function Home() {
  const { open } = useAppKit();
  const { disconnectAsync } = useDisconnect();
  const { isConnected, connector, address } = useAccount();
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();

  const [dataProtector, setDataProtector] =
    useState<IExecDataProtector | null>(null);

  // Invoice data
  const [invoiceData, setInvoiceData] = useState<Invoice>({
    invoice_id: 0,
    invoice_supplier_id: 0,
    invoice_buyer_id: 0,
    invoice_amount: 0,
    invoice_due_date: Math.floor(Date.now() / 1000) + 2592000, // 30 days from now
    invoice_acceptance_timestamp: Math.floor(Date.now() / 1000),
  });

  const [protectedInvoice, setProtectedInvoice] = useState<ProtectedData | null>(null);
  const [isProtecting, setIsProtecting] = useState(false);

  // Grant access state
  const [grantAccessData, setGrantAccessData] = useState({
    zkProofAppAddress: "",
    authorizedUser: "",
    numberOfAccess: 1,
  });
  const [grantedAccess, setGrantedAccess] = useState<GrantedAccess | null>(null);
  const [isGrantingAccess, setIsGrantingAccess] = useState(false);

  // ZK Proof request params
  const [zkProofData, setZkProofData] = useState({
    requiredCreditScore: 700,
    maxAdvanceRate: 80,
  });

  // Task execution state
  const [taskStatus, setTaskStatus] = useState<TaskStatus | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [zkProof, setZkProof] = useState<any | null>(null);

  // ZK Proof App addresses by chain (these would be your deployed iExec apps)
  const zkProofAppAddresses: Record<number, string> = {
    421614: process.env.NEXT_PUBLIC_ZK_PROOF_APP_ADDRESS_ARBITRUM_SEPOLIA || "",
    // Add more chains as needed
  };

  const networks = Object.values(wagmiNetworks);

  const login = () => {
    open({ view: "Connect" });
  };

  const logout = async () => {
    try {
      await disconnectAsync();
    } catch (err) {
      console.error("Failed to logout:", err);
    }
  };

  const handleChainChange = async (
    event: React.ChangeEvent<HTMLSelectElement>
  ) => {
    const selectedChainId = parseInt(event.target.value);
    if (selectedChainId && selectedChainId !== chainId && switchChain) {
      try {
        await switchChain({ chainId: selectedChainId });
      } catch (error) {
        console.error("Failed to switch chain:", error);
      }
    }
  };

  // Get explorer URL for current chain
  const getExplorerUrl = (
    address?: string,
    type: "address" | "dataset" | "apps" | "task" = "address"
  ) => {
    const explorerSlug = explorerSlugs[chainId];
    if (!explorerSlug) return null;

    if (!address) return `https://explorer.iex.ec/${explorerSlug}/${type}`;
    return `https://explorer.iex.ec/${explorerSlug}/${type}/${address}`;
  };

  // Get ZK Proof App address for current chain
  const getCurrentZKProofAppAddress = () => {
    return zkProofAppAddresses[chainId] || "";
  };

  useEffect(() => {
    const initializeDataProtector = async () => {
      if (isConnected && connector) {
        try {
          const provider =
            (await connector.getProvider()) as import("ethers").Eip1193Provider;
          const dp = new IExecDataProtector(provider);
          setDataProtector(dp);
        } catch (error) {
          console.error("Failed to initialize data protector:", error);
        }
      }
    };

    initializeDataProtector();
  }, [isConnected, connector]);

  // Auto-fill ZK Proof App address when chain changes
  useEffect(() => {
    const appAddress = getCurrentZKProofAppAddress();
    if (appAddress) {
      setGrantAccessData((prev) => ({
        ...prev,
        zkProofAppAddress: appAddress,
      }));
    }
  }, [chainId]);

  const protectInvoiceData = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!dataProtector) return;

    setIsProtecting(true);
    try {
      const protectedData = await dataProtector.protectData({
        name: `Invoice-${invoiceData.invoice_id}-${Date.now()}`,
        data: {
          invoice_id: Number(invoiceData.invoice_id),
          invoice_supplier_id: Number(invoiceData.invoice_supplier_id),
          invoice_buyer_id: Number(invoiceData.invoice_buyer_id),
          invoice_amount: Number(invoiceData.invoice_amount),
          invoice_due_date: Number(invoiceData.invoice_due_date),
          invoice_acceptance_timestamp: Number(invoiceData.invoice_acceptance_timestamp),
        },
      });

      console.log("Protected Invoice Data:", protectedData);
      setProtectedInvoice(protectedData);
    } catch (error) {
      console.error("Error protecting invoice data:", error);
    } finally {
      setIsProtecting(false);
    }
  };

  const grantDataAccess = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!dataProtector || !protectedInvoice) return;

    setIsGrantingAccess(true);
    try {
      const result = await dataProtector.grantAccess({
        protectedData: protectedInvoice.address,
        authorizedApp: grantAccessData.zkProofAppAddress,
        authorizedUser: grantAccessData.authorizedUser || address || "",
        numberOfAccess: grantAccessData.numberOfAccess,
      });

      console.log("Granted Access:", result);
      setGrantedAccess(result);
    } catch (error) {
      console.error("Error granting access:", error);
    } finally {
      setIsGrantingAccess(false);
    }
  };

  const processInvoiceWithZKProof = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!dataProtector || !protectedInvoice || !grantedAccess) return;

    setIsProcessing(true);
    setTaskStatus(null);
    setZkProof(null);

    try {
      // This will create a task on iExec network
      const result = await dataProtector.processProtectedData({
        protectedData: protectedInvoice.address,
        app: grantAccessData.zkProofAppAddress,
        // These args would be passed to your ZK proof generator iApp
        args: `--required-credit-score ${zkProofData.requiredCreditScore} --max-advance-rate ${zkProofData.maxAdvanceRate}`,
      });

      console.log("ZK Proof Task Result:", result);
      
      // Update task status based on result
      if (result && typeof result === 'object' && 'taskId' in result) {
        setTaskStatus({
          taskId: (result as any).taskId || "",
          dealId: (result as any).dealId,
          status: 'COMPLETED',
          isDone: true,
          title: "Task completed successfully",
        });
      }
      
      setZkProof(result);
    } catch (error) {
      console.error("Error processing protected data:", error);
      setTaskStatus({
        taskId: "",
        status: 'FAILED',
        isDone: true,
        title: "Task failed",
      });
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="container py-4" style={{ maxWidth: '1200px' }}>
      <nav className="bg-light rounded-3 p-3 mb-4 d-flex justify-content-between align-items-center">
        <div className="d-flex align-items-center gap-3">
          <div className="font-monospace fs-4 fw-bold text-dark">
            ZK Invoice Factoring
          </div>
        </div>
        <div className="d-flex align-items-center gap-3">
          {isConnected && (
            <div className="d-flex align-items-center gap-2">
              <label
                htmlFor="chain-selector"
                className="form-label mb-0 fw-medium text-secondary small"
              >
                Chain:
              </label>
              <select
                id="chain-selector"
                value={chainId}
                onChange={handleChainChange}
                className="form-select form-select-sm"
                style={{ width: 'auto' }}
              >
                {networks?.map((network) => (
                  <option key={network.id} value={network.id}>
                    {network.name}
                  </option>
                ))}
              </select>
            </div>
          )}
          {!isConnected ? (
            <button onClick={login} className="btn btn-primary">
              Connect my wallet
            </button>
          ) : (
            <button onClick={logout} className="btn btn-dark">
              Disconnect
            </button>
          )}
        </div>
      </nav>

      <WelcomeBlock />

      <section className="bg-light rounded-3 p-4">
        {isConnected ? (
          <div>
            {/* Step 1: Protect Invoice Data */}
            <h2 className="mb-4 fs-3 fw-semibold text-dark">
              Step 1: Protect Invoice Data
            </h2>
            <form onSubmit={protectInvoiceData} className="mb-4">
              <div className="row g-3">
                <div className="col-md-6">
                  <label
                    htmlFor="invoice_id"
                    className="form-label fw-medium text-secondary"
                  >
                    Invoice ID *
                  </label>
                  <input
                    onChange={(e) =>
                      setInvoiceData((prev) => ({
                        ...prev,
                        invoice_id: parseInt(e.target.value) || 0,
                      }))
                    }
                    type="number"
                    id="invoice_id"
                    className="form-control"
                    placeholder="12345"
                    value={invoiceData.invoice_id || ""}
                    required
                  />
                </div>

                <div className="col-md-6">
                  <label
                    htmlFor="invoice_amount"
                    className="form-label fw-medium text-secondary"
                  >
                    Invoice Amount (USD) *
                  </label>
                  <input
                    onChange={(e) =>
                      setInvoiceData((prev) => ({
                        ...prev,
                        invoice_amount: parseInt(e.target.value) || 0,
                      }))
                    }
                    type="number"
                    id="invoice_amount"
                    className="form-control"
                    placeholder="50000"
                    value={invoiceData.invoice_amount || ""}
                    required
                  />
                </div>

                <div className="col-md-6">
                  <label
                    htmlFor="supplier_id"
                    className="form-label fw-medium text-secondary"
                  >
                    Supplier ID *
                  </label>
                  <input
                    onChange={(e) =>
                      setInvoiceData((prev) => ({
                        ...prev,
                        invoice_supplier_id: parseInt(e.target.value) || 0,
                      }))
                    }
                    type="number"
                    id="supplier_id"
                    className="form-control"
                    placeholder="67890"
                    value={invoiceData.invoice_supplier_id || ""}
                    required
                  />
                </div>

                <div className="col-md-6">
                  <label
                    htmlFor="buyer_id"
                    className="form-label fw-medium text-secondary"
                  >
                    Buyer ID *
                  </label>
                  <input
                    onChange={(e) =>
                      setInvoiceData((prev) => ({
                        ...prev,
                        invoice_buyer_id: parseInt(e.target.value) || 0,
                      }))
                    }
                    type="number"
                    id="buyer_id"
                    className="form-control"
                    placeholder="11111"
                    value={invoiceData.invoice_buyer_id || ""}
                    required
                  />
                </div>
              </div>

              <div className="mt-4">
                <button
                  disabled={
                    !invoiceData.invoice_id ||
                    !invoiceData.invoice_amount ||
                    isProtecting
                  }
                  className="btn btn-primary"
                  type="submit"
                >
                  {isProtecting ? "Protecting data..." : "Protect Invoice Data"}
                </button>
              </div>
            </form>

            {protectedInvoice && (
              <div className="alert alert-success border-success">
                <h3 className="text-success mb-3 fs-5 fw-semibold">
                  ✅ Invoice data protected successfully!
                </h3>
                <div className="text-success">
                  <p className="mb-2">
                    <strong>Protected Data Address:</strong>{" "}
                    {protectedInvoice.address}
                    {getExplorerUrl(protectedInvoice.address, "dataset") && (
                      <a
                        href={getExplorerUrl(protectedInvoice.address, "dataset")!}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="ms-2 text-success text-decoration-none"
                      >
                        View in Explorer →
                      </a>
                    )}
                  </p>
                  <p className="mb-2">
                    <strong>Transaction Hash:</strong>{" "}
                    {protectedInvoice.creationTimestamp}
                  </p>
                  <p className="mb-0">
                    <strong>Owner:</strong> {protectedInvoice.owner}
                  </p>
                </div>
              </div>
            )}

            {/* Step 2: Grant Access */}
            {protectedInvoice && (
              <div className="mt-5 pt-4 border-top">
                <h2 className="mb-4 fs-3 fw-semibold text-dark">
                  Step 2: Grant Access to ZK Proof Generator
                </h2>
                <form onSubmit={grantDataAccess} className="mb-4">
                  <div className="row g-3">
                    <div className="col-12">
                      <label
                        htmlFor="zk_app_address"
                        className="form-label fw-medium text-secondary"
                      >
                        ZK Proof App Address *
                      </label>
                      <input
                        value={grantAccessData.zkProofAppAddress}
                        onChange={(e) =>
                          setGrantAccessData((prev) => ({
                            ...prev,
                            zkProofAppAddress: e.target.value,
                          }))
                        }
                        type="text"
                        id="zk_app_address"
                        className="form-control"
                        placeholder="0x..."
                        maxLength={42}
                        required
                      />
                      <p className="form-text">
                        The address of the iExec app that will process your data
                      </p>
                    </div>

                    <div className="col-12">
                      <label
                        htmlFor="authorized_user"
                        className="form-label fw-medium text-secondary"
                      >
                        Authorized User (optional)
                      </label>
                      <input
                        value={grantAccessData.authorizedUser}
                        onChange={(e) =>
                          setGrantAccessData((prev) => ({
                            ...prev,
                            authorizedUser: e.target.value,
                          }))
                        }
                        type="text"
                        id="authorized_user"
                        className="form-control"
                        placeholder="0x..."
                        maxLength={42}
                      />
                      <p className="form-text">
                        Leave empty to allow any user to run the app with your data
                      </p>
                    </div>
                  </div>

                  <div className="mt-4">
                    <button
                      disabled={
                        !protectedInvoice ||
                        !grantAccessData.zkProofAppAddress ||
                        isGrantingAccess
                      }
                      className="btn btn-primary"
                      type="submit"
                    >
                      {isGrantingAccess ? "Granting Access..." : "Grant Access"}
                    </button>
                  </div>
                </form>

                {grantedAccess && (
                  <div className="alert alert-success border-success">
                    <h3 className="text-success mb-3 fs-5 fw-semibold">
                      ✅ Access granted successfully!
                    </h3>
                    <div className="text-success">
                      <p className="mb-2">
                        <strong>Authorized App:</strong> {grantedAccess.apprestrict}
                      </p>
                      <p className="mb-0">
                        <strong>Number of Access:</strong> {grantedAccess.volume}
                      </p>
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* Step 3: Generate ZK Proof */}
            {grantedAccess && (
              <div className="mt-5 pt-4 border-top">
                <h2 className="mb-4 fs-3 fw-semibold text-dark">
                  Step 3: Generate ZK Proof with Private Invoice Data
                </h2>
                <form onSubmit={processInvoiceWithZKProof} className="mb-4">
                  <div className="row g-3">
                    <div className="col-12">
                      <label className="form-label fw-medium text-secondary">
                        Protected Invoice Address
                      </label>
                      <input
                        type="text"
                        className="form-control"
                        value={protectedInvoice?.address || ""}
                        disabled
                      />
                    </div>

                    <div className="col-md-6">
                      <label
                        htmlFor="required_credit_score"
                        className="form-label fw-medium text-secondary"
                      >
                        Required Credit Score *
                      </label>
                      <input
                        value={zkProofData.requiredCreditScore}
                        onChange={(e) =>
                          setZkProofData((prev) => ({
                            ...prev,
                            requiredCreditScore: parseInt(e.target.value) || 0,
                          }))
                        }
                        type="number"
                        id="required_credit_score"
                        className="form-control"
                        placeholder="700"
                        min="0"
                        max="850"
                        required
                      />
                    </div>

                    <div className="col-md-6">
                      <label
                        htmlFor="max_advance_rate"
                        className="form-label fw-medium text-secondary"
                      >
                        Max Advance Rate (%) *
                      </label>
                      <input
                        value={zkProofData.maxAdvanceRate}
                        onChange={(e) =>
                          setZkProofData((prev) => ({
                            ...prev,
                            maxAdvanceRate: parseInt(e.target.value) || 0,
                          }))
                        }
                        type="number"
                        id="max_advance_rate"
                        className="form-control"
                        placeholder="80"
                        min="0"
                        max="100"
                        required
                      />
                    </div>
                  </div>

                  <div className="mt-4">
                    <button
                      disabled={
                        !protectedInvoice ||
                        !zkProofData.requiredCreditScore ||
                        !zkProofData.maxAdvanceRate ||
                        isProcessing
                      }
                      className="btn btn-primary"
                      type="submit"
                    >
                      {isProcessing
                        ? "Processing..."
                        : "Generate ZK Proof & Verify"}
                    </button>
                  </div>
                </form>

                {taskStatus && (
                  <div className="alert alert-info border-info">
                    <h3 className="text-info mb-3 fs-5 fw-semibold">
                      Task Status
                    </h3>
                    <div className="text-info">
                      <p className="mb-2">
                        <strong>Status:</strong>{" "}
                        <span className={`task-status ${taskStatus.status.toLowerCase()}`}>
                          {taskStatus.status}
                        </span>
                      </p>
                      <p className="mb-2">
                        <strong>Current Step:</strong> {taskStatus.title}
                      </p>
                      {taskStatus.taskId && (
                        <p className="mb-2">
                          <strong>Task ID:</strong> {taskStatus.taskId}
                          {getExplorerUrl(taskStatus.taskId, "task") && (
                            <a
                              href={getExplorerUrl(taskStatus.taskId, "task")!}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="ms-2 text-info text-decoration-none"
                            >
                              View in Explorer →
                            </a>
                          )}
                        </p>
                      )}
                      {taskStatus.dealId && (
                        <p className="mb-0">
                          <strong>Deal ID:</strong> {taskStatus.dealId}
                        </p>
                      )}
                    </div>
                  </div>
                )}

                {zkProof && (
                  <div className="alert alert-success border-success">
                    <h3 className="text-success mb-3 fs-5 fw-semibold">
                      ✅ ZK Proof Generated Successfully!
                    </h3>
                    <div className="text-success">
                      <p className="mb-2">
                        <strong>Verification:</strong> {zkProof.isEligible ? "✅ Eligible for factoring" : "❌ Not eligible"}
                      </p>
                      <p className="mb-2">
                        <strong>Advance Amount:</strong> ${zkProof.advanceAmount}
                      </p>
                      <p className="mb-0 font-monospace small">
                        <strong>Proof:</strong> {zkProof.proof.substring(0, 100)}...
                      </p>
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        ) : (
          <div className="text-center py-5">
            <p className="text-secondary fs-5 mb-4">
              Please connect your wallet to get started
            </p>
            <button onClick={login} className="btn btn-primary btn-lg">
              Connect Wallet
            </button>
          </div>
        )}
      </section>
    </div>
  );
}
